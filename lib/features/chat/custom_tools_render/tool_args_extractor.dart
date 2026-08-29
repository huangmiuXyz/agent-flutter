/// 工具调用 arguments 的容错解析 — 支持流式未完成的半截 JSON
library;

import 'dart:convert';

/// （可能不完整的）arguments 解析结果：仅保留顶层字段。
class ToolArgs {
  ToolArgs._(this.fields);

  /// 顶层字段：String / num / bool / 嵌套结构的原始 JSON 文本
  final Map<String, Object?> fields;

  String? str(String name) {
    final v = fields[name];
    return v is String ? v : null;
  }

  int? intOf(String name) {
    final v = fields[name];
    return v is num ? v.toInt() : null;
  }

  bool? boolean(String name) {
    final v = fields[name];
    return v is bool ? v : null;
  }
}

/// 解析工具调用 arguments（完整 JSON 或流式中的半截 JSON）。
///
/// 流式期间 arguments 是不断增长的半截 JSON（如 `{"command": "git sta`），
/// 整段 `jsonDecode` 必然失败。这里先尝试完整解码；失败时做前缀容错
/// 解析 —— 逐字符扫描顶层对象的键值对：
/// - 字符串值未闭合时保留已解码前缀（路径/命令随流式渐进显示）；
/// - 数字/字面量值没有终结符（`0` 与 `40` 前缀相同）时不保留，避免
///   短暂闪现错误值；
/// - 嵌套对象/数组完整时保留原文，未闭合时跳过（当前内置工具的参数
///   均为扁平标量，此处只为容错）；
/// - 任何结构破坏（键后缺冒号等）即停止，保留已解析出的字段。
ToolArgs extractToolArgs(String rawArguments) {
  final direct = _tryDecode(rawArguments);
  if (direct != null) return ToolArgs._(direct);
  return ToolArgs._(_parsePrefix(rawArguments));
}

Map<String, Object?>? _tryDecode(String arguments) {
  try {
    final decoded = jsonDecode(arguments);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return null;
}

Map<String, Object?> _parsePrefix(String s) {
  final fields = <String, Object?>{};
  var i = 0;

  void skipWs() {
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c != 0x20 && c != 0x09 && c != 0x0A && c != 0x0D) break;
      i++;
    }
  }

  /// 从 i（指向 `"`）读取字符串。返回 (值, 是否闭合)；未闭合时值已
  /// 按转义规则解码到当前文本末尾。
  (String, bool) readString() {
    i++; // 跳过开引号
    final buf = StringBuffer();
    while (i < s.length) {
      final ch = s[i];
      if (ch == r'\') {
        if (i + 1 >= s.length) return (buf.toString(), false); // 半截转义
        final esc = s[i + 1];
        if (esc == 'u') {
          if (i + 6 > s.length) return (buf.toString(), false);
          final code = int.tryParse(s.substring(i + 2, i + 6), radix: 16);
          if (code == null) {
            // 非法 \u 序列：原样保留，跳过前缀避免死循环
            buf.write(s.substring(i, i + 2));
            i += 2;
            continue;
          }
          buf.writeCharCode(code);
          i += 6;
          continue;
        }
        buf.write(_simpleEscapes[esc] ?? esc);
        i += 2;
        continue;
      }
      if (ch == '"') {
        i++;
        return (buf.toString(), true);
      }
      buf.write(ch);
      i++;
    }
    return (buf.toString(), false);
  }

  /// 从 i（指向 `{` 或 `[`）跳过嵌套结构；完整时返回原始文本。
  (String?, bool) skipNested() {
    final start = i;
    var depth = 0;
    while (i < s.length) {
      final ch = s[i];
      if (ch == '"') {
        final (_, closed) = readString();
        if (!closed) return (null, false);
        continue;
      }
      if (ch == '{' || ch == '[') {
        depth++;
      } else if (ch == '}' || ch == ']') {
        depth--;
        if (depth == 0) {
          i++;
          return (s.substring(start, i), true);
        }
      }
      i++;
    }
    return (null, false);
  }

  /// 读取数字 / true / false / null。未终结（无 `,`/`}` 收尾）时返回
  /// null —— 数字有前缀歧义（`4` 可能是 `40` 的一半），不保留。
  (Object?, bool) readScalar() {
    final start = i;
    while (i < s.length) {
      final ch = s[i];
      if (ch == ',' || ch == '}' || ch == ']' || ch == 0x20 || ch == 0x0A) {
        break;
      }
      i++;
    }
    if (i >= s.length) return (null, false); // 流式中：等下一个 chunk
    final text = s.substring(start, i).trim();
    return (num.tryParse(text) ?? _parseLiteral(text), text.isNotEmpty);
  }

  skipWs();
  if (i >= s.length || s[i] != '{') return fields;
  i++;
  while (true) {
    skipWs();
    if (i >= s.length) break;
    if (s[i] == '}') break;
    if (s[i] == ',') {
      i++;
      continue;
    }
    if (s[i] != '"') break;
    final (key, keyClosed) = readString();
    if (!keyClosed) break;
    skipWs();
    if (i >= s.length || s[i] != ':') break;
    i++;
    skipWs();
    if (i >= s.length) break;
    final ch = s[i];
    if (ch == '"') {
      final (value, closed) = readString();
      fields[key] = value; // 未闭合也保留：路径/命令渐进显示
      if (!closed) break;
    } else if (ch == '{' || ch == '[') {
      final (raw, closed) = skipNested();
      if (!closed) break;
      fields[key] = raw;
    } else {
      final (value, ok) = readScalar();
      if (!ok) break;
      fields[key] = value;
    }
    skipWs();
    if (i >= s.length) break; // 等待 `,` 或 `}`
    if (s[i] == ',') {
      i++;
      continue;
    }
    break; // `}` 或结构破坏：结束
  }
  return fields;
}

Object? _parseLiteral(String text) {
  return switch (text) {
    'true' => true,
    'false' => false,
    'null' => null,
    _ => text,
  };
}

/// JSON 简单转义表（与字符串扫描共用）
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
