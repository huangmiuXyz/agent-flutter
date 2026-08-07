import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_highlight/languages/plaintext.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/markdown/markdown_preview.dart';
import 'package:agent/widgets/text/code_block_view.dart';

/// 收集整棵树上所有文本片段的样式（fontFamily）。
/// 排除图标字体（MaterialIcons 等）；span 无显式样式时收集 Text.rich 的根样式。
List<(String, String?)> _collectFonts(WidgetTester tester) {
  final out = <(String, String?)>[];
  bool isIcon(String? f) => f == 'MaterialIcons';

  for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
    t.text.visitChildren((span) {
      final s = span as TextSpan;
      final plain = s.toPlainText();
      if (plain.isNotEmpty &&
          s.style?.fontFamily != null &&
          !isIcon(s.style!.fontFamily)) {
        out.add((plain, s.style!.fontFamily));
      }
      return true;
    });
  }
  // Text.rich 根样式：HighlightView 等把 textStyle merge 到根样式，
  // 无显式样式的子 span 在渲染时继承它。
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    if (t.style?.fontFamily != null && !isIcon(t.style!.fontFamily)) {
      final plain = t.textSpan?.toPlainText() ?? t.data ?? '';
      if (plain.isNotEmpty) {
        out.add((plain, t.style!.fontFamily));
      }
    }
  }
  return out;
}

void main() {
  const testFont = 'TestCJKFont';
  final testStyle = const TextStyle(
    fontFamily: testFont,
    fontSize: 14,
    color: Colors.black,
  );

  void expectAllFollow(String label, List<(String, String?)> fonts) {
    final bad = fonts.where((f) => f.$2 != testFont).toList();
    if (bad.isEmpty) {
      debugPrint('=== $label: 全部片段跟随字体 $testFont ✓ ===');
    } else {
      debugPrint('=== $label: 以下片段未跟随字体 ===');
      for (final b in bad) {
        debugPrint('  "${b.$1}" -> ${b.$2}');
      }
    }
    expect(bad, isEmpty, reason: '$label 存在不跟随字体的片段: $bad');
  }

  testWidgets('标题跟随字体', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownPreview(
              text: '## 1. 经典冒泡排序（双层 for 循环）',
              textStyle: testStyle,
            ),
          ),
        ),
      ),
    );
    expectAllFollow('标题', _collectFonts(tester));
  });

  testWidgets('列表项序号跟随字体', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownPreview(
              text: '1. 经典冒泡排序（双层 for 循环）',
              textStyle: testStyle,
            ),
          ),
        ),
      ),
    );
    expectAllFollow('有序列表', _collectFonts(tester));
  });

  testWidgets('代码块与行内代码跟随字体', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownPreview(
              text: '正文和`行内代码`混排\n\n```dart\n// 中文注释\nfinal a = 1;\n```',
              textStyle: testStyle,
            ),
          ),
        ),
      ),
    );
    expectAllFollow('代码块+行内代码', _collectFonts(tester));
  });

  testWidgets('CodeBlockView（chat 代码块）跟随字体', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [
            CustomTheme.resolve(Brightness.light, fontFamily: testFont),
          ],
        ),
        home: Scaffold(
          body: CodeBlockView(
            code: '// 中文注释\nfinal a = 1;',
            language: langPlaintext,
          ),
        ),
      ),
    );
    expectAllFollow('CodeBlockView', _collectFonts(tester));
  });

  testWidgets('字号缩放：标题与代码块字号随 fontSizeScale 变化', (tester) async {
    const scale = 1.5;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [
            CustomTheme.resolve(
              Brightness.light,
              fontFamily: testFont,
              fontSizeScale: scale,
            ),
          ],
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownPreview(
              // 无语言代码块走普通 Text 路径（span 携带显式样式）
              text: '## 标题\n\n```\n// 注释\n```',
              textStyle: const TextStyle(
                fontFamily: testFont,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );

    // 标题：Material 默认 headlineMedium = 28，缩放后 = 42
    bool headingOk = false;
    bool codeOk = false;
    for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
      t.text.visitChildren((span) {
        final s = span as TextSpan;
        final plain = s.toPlainText();
        if (plain == '标题') {
          headingOk = (s.style?.fontSize ?? 0) == 42;
        }
        if (plain == '// 注释') {
          // 13 * 1.5 = 19.5
          codeOk = (s.style?.fontSize ?? 0) == 19.5;
        }
        return true;
      });
    }
    expect(headingOk, isTrue, reason: '标题字号未随 fontSizeScale 缩放');
    expect(codeOk, isTrue, reason: '代码块字号未随 fontSizeScale 缩放');
  });
}
