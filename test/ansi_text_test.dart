import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/widgets/ansi_text.dart';

void main() {
  group('AnsiTextParser', () {
    test('纯文本无转义：单个 span 原样输出', () {
      final spans = AnsiTextParser().parse('hello world');
      expect(spans.length, 1);
      expect(spans.single.text, 'hello world');
    });

    test('16 色前景：绿色文字', () {
      final spans = AnsiTextParser().parse('\x1b[32mgreen\x1b[0m');
      expect(spans.length, 1);
      expect(spans[0].text, 'green');
      expect(spans[0].style?.color, const Color(0xFF00C200));
    });

    test('粗体加颜色', () {
      final spans = AnsiTextParser().parse('\x1b[1;32mbold green\x1b[0m');
      expect(spans[0].style?.fontWeight, FontWeight.bold);
      expect(spans[0].style?.color, const Color(0xFF00C200));
    });

    test('重置回到 base 样式', () {
      const base = TextStyle(color: Colors.white);
      final spans = AnsiTextParser().parse(
        'a\x1b[31mred\x1b[0mb',
        baseStyle: base,
      );
      expect(spans[0].style?.color, Colors.white);
      expect(spans[1].style?.color, const Color(0xFFC91B00));
      expect(spans[2].style?.color, Colors.white);
      expect(spans[2].text, 'b');
    });

    test('256 色：索引 196 为亮红', () {
      final spans = AnsiTextParser().parse('\x1b[38;5;196mx\x1b[0m');
      expect(spans[0].style?.color, const Color(0xFFFF0000));
    });

    test('truecolor', () {
      final spans = AnsiTextParser().parse('\x1b[38;2;10;20;30mx\x1b[0m');
      expect(spans[0].style?.color, const Color.fromARGB(255, 10, 20, 30));
    });

    test('不支持的序列（光标移动）被丢弃且不影响文本', () {
      final spans = AnsiTextParser().parse('a\x1b[2Kb');
      final combined = spans.map((s) => s.text ?? '').join();
      expect(combined, 'ab');
      expect(combined.contains('\x1b'), false);
    });
  });
}
