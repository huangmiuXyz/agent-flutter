/// apply_patch 工具 arguments 的容错解析 — 支持流式未完成的半截 JSON
library;

import 'dart:convert';

/// 定位 arguments JSON 中 `"patch":` 键的起始位置（键后可有空白）
final RegExp _patchKeyRe = RegExp(r'"patch"\s*:');

/// 合法简单转义（`\n` 等）；值出现非法转义时退化原样输出
const Map<String, String> _simpleEscapes = {
  '"': '"',
  r'\': r'\',
  '/': '/',
  'b': '\b',
  'f': '\f',
  'n': '\n',
  'r': '\r',
  't': '\t',
};

final RegExp _nonHexRe = RegExp(r'[^0-9a-fA-F]');

/// 从（可能流式未完成的）arguments JSON 中容错提取 `patch` 字段值。
///
/// 流式期间 arguments 是不断增长的半截 JSON（如
/// `{"patch": "*** Begin Patch...`），整段 `jsonDecode` 必然失败。
/// 这里不要求整段 JSON 合法：定位 `"patch":` 后扫描其字符串值，
/// 正确处理 `\"` / `\\` 等转义；字符串未闭合（仍在流式）时取全部
/// 剩余文本，未完成的转义序列在下一片段补全。
///
/// 返回 null 表示 patch 键尚未出现或其值不是字符串；
/// 返回空串表示 patch 值已出现但为空（同"暂不渲染"）。
///
/// 一次性调用入口：内部新建无状态的提取器全量扫描。
/// 流式场景请复用 [StreamingPatchExtractor]，避免每 chunk 重复
/// 扫描已处理的文本（长 patch 下 O(n²)）。
String? extractStreamingPatch(String rawArguments) {
  return StreamingPatchExtractor().extract(rawArguments);
}

/// 流式增量 patch 提取器 — 跨 chunk 保状态，每 chunk 只处理新增文本。
///
/// 流式期间每次传入的 arguments 都是「前缀追加」（相同前缀 + 新尾部）：
/// - 上次已扫描的文本不再重扫，只处理增量；
/// - 转义序列逐字符解码（`\n` → 换行等），chunk 边界被截断的转义
///   留在 pending，下一 chunk 补全后写入；
/// - patch 值字符串闭合后结果定型，尾部增长（`"}` 等）直接复用。
///
/// 非追加场景（工具完成覆盖为合法 JSON / 重试 / 历史加载）自动重置：
/// 完整合法 JSON 直接 `jsonDecode` 读取 `patch` 键（含引号的补丁
/// 不会被字符串扫描误截断）；否则全量重扫。
class StreamingPatchExtractor {
  /// 上一轮完整 arguments（前缀追加判定用）
  String? _last;

  /// `"patch":` 键扫描结束位置（-1 = 尚未找到）
  int _keyEnd = -1;

  /// patch 字符串值开引号后的起始位置（-1 = 尚未进入值）
  int _valueStart = -1;

  /// 值字符串是否已闭合（此后内容不再参与解码）
  bool _closed = false;

  /// 值字符串闭合位置（`_closed` 时有效）
  int _closePos = 0;

  /// 已解码的 patch 前缀（未闭合时即当前结果）
  final StringBuffer _decoded = StringBuffer();

  /// 未完成的转义序列（如 chunk 末尾的 `\`、`\u12`），补全后解码写入
  String _pendingEscape = '';

  /// 出现过非法转义：退化原样输出（对齐一次性解析的解码失败回退）
  bool _decodeFailed = false;

  /// `"patch":` 后不是字符串值（如数字）：恒返回 null
  bool _invalidValue = false;

  /// 上一轮结果缓存（相同输入直接返回，不重复扫描）
  String? _cached;

  /// 提取 patch；返回语义同 [extractStreamingPatch]
  String? extract(String arguments) {
    if (arguments == _last) return _cached;
    final isAppend =
        _last != null &&
        arguments.length > _last!.length &&
        arguments.startsWith(_last!);
    final oldLength = _last?.length ?? 0;
    if (!isAppend) {
      // 整体替换（工具完成覆盖为已解码 arguments / 重试 / 历史加载）：
      // 完整合法 JSON 直接取键，避免字符串扫描误截断含引号的补丁
      _reset();
      final direct = _tryDecodePatch(arguments);
      if (direct != null) {
        _last = arguments;
        _cached = direct;
        return direct;
      }
    }
    _last = arguments;
    final result = isAppend ? _scan(arguments, oldLength) : _scan(arguments, 0);
    _cached = result;
    return result;
  }

  void _reset() {
    _keyEnd = -1;
    _valueStart = -1;
    _closed = false;
    _closePos = 0;
    _decoded.clear();
    _pendingEscape = '';
    _decodeFailed = false;
    _invalidValue = false;
  }

  /// arguments 是完整合法 JSON 时直接读 `patch` 键；否则返回 null
  String? _tryDecodePatch(String arguments) {
    try {
      final decoded = jsonDecode(arguments);
      if (decoded is Map<String, dynamic>) {
        final patch = decoded['patch'];
        if (patch is String) return patch;
      }
    } catch (_) {}
    return null;
  }

  /// 从 [from] 起扫描新文本；返回当前 patch 提取结果
  String? _scan(String text, int from) {
    if (_closed) return _result(text);
    if (_keyEnd < 0) {
      final key = _patchKeyRe.firstMatch(text);
      if (key == null) return null;
      _keyEnd = key.end;
    }
    if (!_inValue()) {
      var i = _keyEnd;
      while (i < text.length && (text[i] == ' ' || text[i] == '\t')) {
        i++;
      }
      if (i >= text.length) return null;
      if (text[i] != '"') {
        _invalidValue = true;
        return null;
      }
      _valueStart = i + 1;
      if (from < _valueStart) from = _valueStart;
    }
    for (var i = from; i < text.length; i++) {
      final ch = text[i];
      if (_pendingEscape.isNotEmpty) {
        _stepEscape(ch);
        continue;
      }
      if (ch == r'\') {
        _pendingEscape = r'\';
        continue;
      }
      if (ch == '"') {
        _closed = true;
        _closePos = i;
        break;
      }
      _decoded.write(ch);
    }
    return _result(text);
  }

  bool _inValue() => _valueStart >= 0;

  /// 追加一个转义序列字符；序列完整（或非法终结）时解码写入，
  /// 返回序列是否已终结
  bool _stepEscape(String ch) {
    _pendingEscape += ch;
    final seq = _pendingEscape;
    if (seq.length < 2) return false; // 单独的 `\`，等下一字符
    if (seq[1] == 'u') {
      if (seq.length < 6) {
        final digits = seq.substring(2);
        // 已出现非十六进制字符 → 非法 `\u` 序列，立即终结
        if (_nonHexRe.hasMatch(digits)) return _failEscape();
        return false; // 等剩余 hex 位
      }
      final code = int.tryParse(seq.substring(2), radix: 16);
      if (code != null) {
        _decoded.writeCharCode(code);
      } else {
        return _failEscape();
      }
      _pendingEscape = '';
      return true;
    }
    final mapped = _simpleEscapes[seq[1]];
    if (mapped != null) {
      _decoded.write(mapped);
      _pendingEscape = '';
      return true;
    }
    return _failEscape();
  }

  /// 非法转义：标记解码失败（后续整体原样输出），写入原始序列
  bool _failEscape() {
    _decodeFailed = true;
    _decoded.write(_pendingEscape);
    _pendingEscape = '';
    return true;
  }

  String? _result(String text) {
    if (_keyEnd < 0 || !_inValue() || _invalidValue) return null;
    if (_decodeFailed) {
      // 退化：返回带转义的原始值文本（对齐一次性解析的失败回退）
      return text.substring(_valueStart, _closed ? _closePos : text.length);
    }
    return _decoded.toString();
  }
}
