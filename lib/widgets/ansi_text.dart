/// ANSI SGR 渲染器 — 把终端输出的转义序列解析为带样式的 TextSpan。
///
/// 用途：`shell_command` 等工具返回的文本保留 ANSI 颜色码（与 codex 的
/// ansi-to-tui 思路一致），由本解析器渲染为彩色文本；不支持的序列
/// （光标移动、OSC 等）按原样丢弃。
///
/// 支持：
/// - 16 色（30-37 / 90-97 前景，40-47 / 100-107 背景）
/// - 256 色（38;5;n / 48;5;n）
/// - truecolor（38;2;r;g;b / 48;2;r;g;b）
/// - 粗体 / 斜体 / 下划线 / 反转 / 重置（0）
library;

import 'package:flutter/material.dart';

class AnsiTextParser {
  /// 标准 16 色 ANSI 调色板（索引对应 SGR 30-37 与 90-97）。
  static const List<Color> _palette = [
    Color(0xFF000000), // 30 black
    Color(0xFFC91B00), // 31 red
    Color(0xFF00C200), // 32 green
    Color(0xFFC7C400), // 33 yellow
    Color(0xFF0225C7), // 34 blue
    Color(0xFFC930C7), // 35 magenta
    Color(0xFF00C5C7), // 36 cyan
    Color(0xFFC7C7C7), // 37 white
    Color(0xFF686868), // 90 bright black
    Color(0xFFFF6E67), // 91 bright red
    Color(0xFF5FF967), // 92 bright green
    Color(0xFFFEFB67), // 93 bright yellow
    Color(0xFF6871FF), // 94 bright blue
    Color(0xFFFF77FF), // 95 bright magenta
    Color(0xFF5FFDFF), // 96 bright cyan
    Color(0xFFFFFFFF), // 97 bright white
  ];

  /// 解析 [text] 为 TextSpan 列表。[baseStyle] 提供默认样式，
  /// ANSI 指定样式优先；重置（SGR 0 / 39 / 49）回到 base。
  List<TextSpan> parse(String text, {TextStyle? baseStyle}) {
    final spans = <TextSpan>[];
    final buffer = StringBuffer();
    Color? fg;
    Color? bg;
    var bold = false;
    var italic = false;
    var underline = false;
    var reverse = false;

    void flush() {
      if (buffer.isEmpty) return;
      var style = TextStyle(
        color: fg,
        backgroundColor: bg,
        fontWeight: bold ? FontWeight.bold : null,
        fontStyle: italic ? FontStyle.italic : null,
        decoration: underline ? TextDecoration.underline : null,
      );
      if (baseStyle != null) {
        // 注意 merge 方向：`base.merge(ansi)` — ansi 的非 null 属性覆盖 base
        style = baseStyle.merge(style);
      }
      if (reverse) {
        // 反转：前景/背景互换（无背景时用 base 前景色兜底）
        style = style.copyWith(
          color: style.backgroundColor ?? baseStyle?.color,
          backgroundColor: style.color,
        );
      }
      spans.add(TextSpan(text: buffer.toString(), style: style));
      buffer.clear();
    }

    void applySgr(String params) {
      // 空参数等价于 SGR 0（重置）
      if (params.isEmpty) {
        fg = null;
        bg = null;
        bold = italic = underline = reverse = false;
        return;
      }
      final codes = params.split(';');
      var i = 0;
      while (i < codes.length) {
        final code = int.tryParse(codes[i]) ?? 0;
        // 38/48 带模式参数（5;n 或 2;r;g;b）
        if (code == 38 || code == 48) {
          final setColor = code == 38
              ? (Color c) => fg = c
              : (Color c) => bg = c;
          if (i + 1 < codes.length) {
            final mode = int.tryParse(codes[i + 1]) ?? 0;
            if (mode == 5 && i + 2 < codes.length) {
              setColor(_color256(int.tryParse(codes[i + 2]) ?? 0));
              i += 3;
              continue;
            }
            if (mode == 2 && i + 4 < codes.length) {
              setColor(
                Color.fromARGB(
                  255,
                  int.tryParse(codes[i + 2]) ?? 0,
                  int.tryParse(codes[i + 3]) ?? 0,
                  int.tryParse(codes[i + 4]) ?? 0,
                ),
              );
              i += 5;
              continue;
            }
          }
        }
        switch (code) {
          case 0:
            fg = null;
            bg = null;
            bold = italic = underline = reverse = false;
          case 1:
            bold = true;
          case 3:
            italic = true;
          case 4:
            underline = true;
          case 7:
            reverse = true;
          case 22:
            bold = false;
          case 23:
            italic = false;
          case 24:
            underline = false;
          case 27:
            reverse = false;
          case 39:
            fg = null;
          case 49:
            bg = null;
          default:
            if (code >= 30 && code <= 37) {
              fg = _palette[code - 30];
            } else if (code >= 40 && code <= 47) {
              bg = _palette[code - 40];
            } else if (code >= 90 && code <= 97) {
              fg = _palette[code - 90 + 8];
            } else if (code >= 100 && code <= 107) {
              bg = _palette[code - 100 + 8];
            }
        }
        i++;
      }
    }

    // CSI 序列：`ESC[参数+字母`（m=颜色，K/J/H 等光标控制均丢弃）；
    // OSC 序列：`ESC]...BEL 或 ESC]...ESC\`（标题等，丢弃）
    final sequence = RegExp(
      r'\x1B(?:\[([0-9;?]*)([A-Za-z])|\][^\x07\x1b]*(?:\x07|\x1B\\))',
    );
    var lastEnd = 0;
    for (final m in sequence.allMatches(text)) {
      if (m.start > lastEnd) {
        buffer.write(text.substring(lastEnd, m.start));
      }
      flush();
      // 仅 SGR（m 结尾）应用样式，其余 CSI/OSC 丢弃
      if (m.group(2) == 'm') {
        applySgr(m.group(1) ?? '');
      }
      lastEnd = m.end;
    }
    if (lastEnd < text.length) {
      buffer.write(text.substring(lastEnd));
    }
    flush();
    return spans;
  }

  /// 256 色索引 → Color：16-231 为 6×6×6 立方体，232-255 为灰度。
  Color _color256(int idx) {
    if (idx < 16) return _palette[idx];
    if (idx < 232) {
      final v = idx - 16;
      final r = (v ~/ 36) % 6;
      final g = (v ~/ 6) % 6;
      final b = v % 6;
      int scale(int c) => c == 0 ? 0 : 55 + c * 40;
      return Color.fromARGB(255, scale(r), scale(g), scale(b));
    }
    final gray = 8 + (idx - 232) * 10;
    return Color.fromARGB(255, gray, gray, gray);
  }
}

/// 便捷 widget：把含 ANSI 转义的文本渲染为可选中的彩色文本。
class AnsiText extends StatelessWidget {
  const AnsiText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(
        style: style,
        children: AnsiTextParser().parse(text, baseStyle: style),
      ),
    );
  }
}
