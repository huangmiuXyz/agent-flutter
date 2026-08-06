/// apply_patch 工具 arguments 的容错解析 — 支持流式未完成的半截 JSON
library;

import 'dart:convert';

/// 定位 arguments JSON 中 `"patch":` 键的起始位置（键后可有空白）
final RegExp _patchKeyRe = RegExp(r'"patch"\s*:');

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
String? extractStreamingPatch(String rawArguments) {
  final keyMatch = _patchKeyRe.firstMatch(rawArguments);
  if (keyMatch == null) return null;
  var i = keyMatch.end;
  while (i < rawArguments.length &&
      (rawArguments[i] == ' ' || rawArguments[i] == '\t')) {
    i++;
  }
  if (i >= rawArguments.length || rawArguments[i] != '"') return null;
  i++; // 跳过开引号
  final raw = StringBuffer();
  var escaped = false;
  for (; i < rawArguments.length; i++) {
    final ch = rawArguments[i];
    if (escaped) {
      raw.write(ch);
      escaped = false;
    } else if (ch == '\\') {
      raw.write(ch);
      escaped = true;
    } else if (ch == '"') {
      // 字符串已闭合：整体是合法 JSON 字符串，解码还原转义序列
      return _decodePatchString(raw);
    } else {
      raw.write(ch);
    }
  }
  // 字符串未闭合（仍在流式）：解码失败时保留原文
  return _decodePatchString(raw);
}

/// 将扫描到的原始内容作为 JSON 字符串解码；失败（未完成的转义/未转义
/// 换行等）时原样返回，diff 渲染按 `\n` 分行不受影响
String _decodePatchString(StringBuffer raw) {
  final encoded = '"${raw.toString()}"';
  try {
    return jsonDecode(encoded) as String;
  } catch (_) {
    return raw.toString();
  }
}
