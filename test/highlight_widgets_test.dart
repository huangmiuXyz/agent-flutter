import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:re_highlight/languages/dart.dart';

import 'package:agent/features/chat/custom_tools_render/chat_diff_block.dart';
import 'package:agent/features/chat/custom_tools_render/diff_code_block.dart';
import 'package:agent/features/chat/widgets/chat_text_part.dart';
import 'package:agent/theme/app_colors.dart';
import 'package:agent/theme/app_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/code_block_view.dart';
import 'package:agent/widgets/text/highlight_text.dart';

/// 收集 TextSpan 树中所有 (文本, 样式) 段
List<(String, TextStyle?)> _segments(
  InlineSpan span, [
  List<(String, TextStyle?)>? out,
]) {
  final acc = out ?? <(String, TextStyle?)>[];
  if (span is TextSpan) {
    if (span.text != null && span.text!.isNotEmpty) {
      acc.add((span.text!, span.style));
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      _segments(child, acc);
    }
  }
  return acc;
}

(String, TextStyle?) _segFor(List<(String, TextStyle?)> segs, String text) =>
    segs.firstWhere((s) => s.$1 == text);

/// 收集所有内容行（SelectableText）的 (完整文本, 行级 span 段)
List<(String, List<(String, TextStyle?)>)> _contentLines(
  WidgetTester tester, {
  required Type of,
}) {
  return tester
      .widgetList<SelectableText>(
        find.descendant(
          of: find.byType(of),
          matching: find.byType(SelectableText),
        ),
      )
      .map(
        (t) => (
          t.data ?? t.textSpan!.toPlainText(),
          _segments(t.textSpan ?? TextSpan(text: t.data)),
        ),
      )
      .toList();
}

/// 收集每行的行号（单列弱色 Text；过滤文件头徽标/路径/统计等非数字文本）
List<String> _lineNos(WidgetTester tester, {required Type of}) {
  return tester
      .widgetList<Text>(
        find.descendant(of: find.byType(of), matching: find.byType(Text)),
      )
      .map((t) => t.data ?? '')
      .where((d) => RegExp(r'^\d+$').hasMatch(d))
      .toList();
}

Widget _wrap(Widget child) => MaterialApp(
  theme: appLightTheme,
  home: Scaffold(body: child),
);

void main() {
  const patch =
      '*** Begin Patch\n'
      '*** Add File: lib/a.dart\n'
      '+void main() {}\n'
      '*** Update File: lib/b.dart\n'
      '@@ -1,2 +1,2 @@\n'
      '-old\n'
      '+new\n'
      '\\ No newline at end of file\n'
      '*** End Patch';

  group('ChatDiffBlock', () {
    testWidgets('diff 视图：隐藏语法噪音、内容去符号、绿红背景', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatDiffBlock(
            diff: '*** Begin Patch\n'
                '*** Update File: test/hello.txt\n'
                '@@\n'
                ' Hello, apply_patch!\n'
                ' This is a test file.\n'
                '-Added a new line.\n'
                '*** End Patch',
          ),
        ),
      );

      // 语法噪音不渲染：信封行 / hunk 头 / 符号前缀
      expect(find.textContaining('*** Begin Patch'), findsNothing);
      expect(find.textContaining('*** End Patch'), findsNothing);
      expect(find.textContaining('*** Update File'), findsNothing);
      expect(find.textContaining('@@'), findsNothing);
      expect(find.textContaining('+Added'), findsNothing);
      expect(find.textContaining('-Added'), findsNothing);

      // 文件头：操作图标 + 路径 + 变更统计
      expect(find.byType(AppIcon), findsOneWidget);
      expect(find.text('test/hello.txt'), findsOneWidget);

      // 内容行：去符号/前缀后的文本（规范格式：上下文 1 空格前缀被去掉）
      final lineTexts = _contentLines(tester, of: DiffCodeBlock)
          .map((l) => l.$1)
          .toList();
      expect(lineTexts, contains('Added a new line.'));
      expect(lineTexts, contains('Hello, apply_patch!'));
      expect(lineTexts, contains('This is a test file.'));

      // 内容列对齐：所有内容行不以空格开头（前缀已统一去掉）
      for (final t in lineTexts) {
        expect(t.startsWith(' '), isFalse, reason: '缩进错位: "$t"');
      }

      // 行背景：删除行 danger 8%，上下文行无背景
      final lineBgs = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(DiffCodeBlock),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.color)
          .toList();
      final light = AppColors.light;
      expect(lineBgs, contains(light.danger.withValues(alpha: 0.08)));
      expect(lineBgs, contains(null));

      // 行内容可选中（行号为不可选中的普通 Text，复制不含行号）
      expect(
        find.descendant(
          of: find.byType(DiffCodeBlock),
          matching: find.byType(SelectableText),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('非规范前缀风格（无上下文空格 + `- 内容`）：同样对齐', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatDiffBlock(
            diff: '*** Begin Patch\n'
                '*** Update File: test/hello.txt\n'
                '@@\n'
                'Hello, apply_patch!\n'
                'This is a test file.\n'
                '- Added a new line.\n'
                '*** End Patch',
          ),
        ),
      );
      final lineTexts = _contentLines(tester, of: DiffCodeBlock)
          .map((l) => l.$1)
          .toList();
      // 删除行 `- Added` 的对齐空格被去掉，与上下文行同起点
      expect(lineTexts, contains('Added a new line.'));
      expect(lineTexts, contains('Hello, apply_patch!'));
      for (final t in lineTexts) {
        expect(t.startsWith(' '), isFalse, reason: '缩进错位: "$t"');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('内容本身的缩进保留（代码缩进行）', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatDiffBlock(
            diff: '*** Begin Patch\n'
                '*** Update File: a.dart\n'
                '@@\n'
                '     oldIndent\n'
                '-    removedLine\n'
                '+    addedLine\n'
                '*** End Patch',
          ),
        ),
      );
      final lineTexts = _contentLines(tester, of: DiffCodeBlock)
          .map((l) => l.$1)
          .toList();
      // 规范格式：上下文 `     oldIndent`（前缀 1 空格 + 内容 4 空格缩进）
      // → 去前缀后与增删行内容（4 空格缩进）对齐
      expect(lineTexts, contains('    oldIndent'));
      expect(lineTexts, contains('    removedLine'));
      expect(lineTexts, contains('    addedLine'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('文件头：徽标、路径与统计，+ 行 / - 行只显内容', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatDiffBlock(
            diff: '*** Begin Patch\n'
                '*** Add File: lib/a.dart\n'
                '+void main() {}\n'
                '+// comment\n'
                '*** Delete File: old.txt\n'
                '-gone\n'
                '*** Move File: x.dart -> y.dart\n'
                ' context\n'
                '*** End Patch',
          ),
        ),
      );
      // 文件头：操作图标（新建/删除/移动）+ 路径 + 统计
      expect(find.byType(AppIcon), findsNWidgets(3));
      expect(find.text('lib/a.dart'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget); // 新建块 2 个新增行
      expect(find.text(' −1'), findsOneWidget); // 删除块 1 个删除行
      // 只显示去符号后的内容
      final lineTexts = _contentLines(tester, of: DiffCodeBlock)
          .map((l) => l.$1)
          .toList();
      expect(lineTexts, contains('void main() {}'));
      expect(lineTexts, contains('gone'));
      expect(lineTexts, contains('context'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('内容行按文件语言 token 高亮（dart 关键字/字符串）', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatDiffBlock(
            diff: '*** Begin Patch\n'
                '*** Update File: lib/main.dart\n'
                '@@\n'
                '+void main() {\n'
                '+  print("hi");\n'
                '-final old = 1;\n'
                '*** End Patch',
          ),
        ),
      );

      // 每行的 token 段：关键字 warning 色、字符串 success 色
      final light = AppColors.light;
      final lineSpans = _contentLines(tester, of: DiffCodeBlock);

      // `+void main() {` → void 为关键字（warning 色）
      final voidLine = lineSpans.firstWhere((l) => l.$1 == 'void main() {');
      final voidSeg = voidLine.$2.firstWhere((s) => s.$1 == 'void');
      expect(voidSeg.$2?.color, light.warning);

      // `+  print("hi");` → 内容缩进保留（2 空格）+ 字符串 success 色
      final printLine = lineSpans.firstWhere(
        (l) => l.$1 == '  print("hi");',
      );
      final stringSeg = printLine.$2.firstWhere((s) => s.$1 == '"hi"');
      expect(stringSeg.$2?.color, light.success);

      // `-final old = 1;` → final 关键字（warning 色），行背景为红
      final removedLine = lineSpans.firstWhere((l) => l.$1 == 'final old = 1;');
      final finalSeg = removedLine.$2.firstWhere((s) => s.$1 == 'final');
      expect(finalSeg.$2?.color, light.warning);
      expect(tester.takeException(), isNull);
    });

    testWidgets('未知扩展名文件：纯文本无 token 高亮', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatDiffBlock(
            diff: '*** Begin Patch\n'
                '*** Update File: test/hello.txt\n'
                '@@\n'
                '+Added a new line.\n'
                '*** End Patch',
          ),
        ),
      );
      // txt 无映射语言 → 单段无样式文本（无 token 颜色）
      final lineSpans = _contentLines(tester, of: DiffCodeBlock);
      final addedLine = lineSpans.firstWhere((l) => l.$1 == 'Added a new line.');
      expect(addedLine.$2.length, 1);
      expect(addedLine.$2.single.$2, isNull); // 无样式
      expect(tester.takeException(), isNull);
    });

    testWidgets('多文件块语言切换：dart 与 rust 各自高亮', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatDiffBlock(
            diff: '*** Begin Patch\n'
                '*** Add File: lib/a.dart\n'
                '+void main() {}\n'
                '*** Add File: src/b.rs\n'
                '+fn main() {}\n'
                '*** End Patch',
          ),
        ),
      );
      final light = AppColors.light;
      final lineSpans = _contentLines(tester, of: DiffCodeBlock);

      final dartLine = lineSpans.firstWhere((l) => l.$1 == 'void main() {}');
      expect(
        dartLine.$2.firstWhere((s) => s.$1 == 'void').$2?.color,
        light.warning,
      );

      final rustLine = lineSpans.firstWhere((l) => l.$1 == 'fn main() {}');
      expect(
        rustLine.$2.firstWhere((s) => s.$1 == 'fn').$2?.color,
        light.warning,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('行号：hunk 头重置、双列旧|新、增删行各显一列', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatDiffBlock(
            diff: '*** Begin Patch\n'
                '*** Update File: test/hello.txt\n'
                '@@ -3,2 +5,2 @@\n'
                ' Hello, apply_patch!\n'
                ' This is a test file.\n'
                '-Added a new line.\n'
                '+New content here.\n'
                ' context\n'
                '*** End Patch',
          ),
        ),
      );

      final lines = _contentLines(tester, of: DiffCodeBlock).toList();
      final nos = _lineNos(tester, of: DiffCodeBlock);
      expect(lines.length, nos.length);

      // 上下文行：hunk 头 `-3 +5` 起递增（单列新行号）
      final helloIdx = lines.indexWhere((l) => l.$1 == 'Hello, apply_patch!');
      expect(nos[helloIdx], '5');
      expect(nos[helloIdx + 1], '6');

      // 删除行：无新行号，显示旧行号
      final removedIdx = lines.indexWhere((l) => l.$1 == 'Added a new line.');
      expect(nos[removedIdx], '5');

      // 新增行：显示新行号
      final addedIdx = lines.indexWhere((l) => l.$1 == 'New content here.');
      expect(nos[addedIdx], '7');

      // 上下文行继续递增
      final ctxIdx = lines.indexWhere((l) => l.$1 == 'context');
      expect(nos[ctxIdx], '8');
      expect(tester.takeException(), isNull);
    });

    testWidgets('行号：Add File 无 hunk 头从 1 起，文件头归零', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatDiffBlock(
            diff: '*** Begin Patch\n'
                '*** Add File: lib/a.dart\n'
                '+void main() {}\n'
                '*** Add File: lib/b.dart\n'
                '+fn main() {}\n'
                '*** End Patch',
          ),
        ),
      );
      final lines = _contentLines(tester, of: DiffCodeBlock).toList();
      final nos = _lineNos(tester, of: DiffCodeBlock);
      // 第一个文件：新行号 1；第二个文件归零重新从 1
      final first = lines.indexWhere((l) => l.$1 == 'void main() {}');
      final second = lines.indexWhere((l) => l.$1 == 'fn main() {}');
      expect(nos[first], '1');
      expect(nos[second], '1');
      expect(tester.takeException(), isNull);
    });

    testWidgets('流式更新：diff 变化同步到渲染', (tester) async {
      await tester.pumpWidget(_wrap(ChatDiffBlock(diff: '*** Begin Patch\n')));

      // 模拟流式追加
      await tester.pumpWidget(_wrap(ChatDiffBlock(diff: '$patch\n')));
      final view = tester.widget<DiffCodeBlock>(find.byType(DiffCodeBlock));
      expect(view.diff, '$patch\n');
      expect(tester.takeException(), isNull);
    });

    testWidgets('空 diff 不渲染', (tester) async {
      await tester.pumpWidget(_wrap(const ChatDiffBlock(diff: '')));
      expect(find.byType(DiffCodeBlock), findsNothing);
    });
  });

  group('ChatTextPart', () {
    testWidgets('消息正文的 diff 代码块：VSCode 绿红行背景', (tester) async {
      await tester.pumpWidget(
        _wrap(ChatTextPart(content: '```diff\n+added\n-removed\n```')),
      );

      // diff 语言走 DiffCodeBlock，其他语言走 CodeBlockView
      expect(find.byType(DiffCodeBlock), findsOneWidget);
      expect(find.byType(CodeBlockView), findsNothing);

      // 去符号后的内容行：主色文字 + 绿/红行背景（无语言时纯文本）
      final lineTexts = _contentLines(tester, of: DiffCodeBlock).toList();
      final added = lineTexts.firstWhere((l) => l.$1 == 'added');
      final removed = lineTexts.firstWhere((l) => l.$1 == 'removed');
      expect(added.$1, 'added');
      expect(removed.$1, 'removed');
      final light = AppColors.light;
      final lineBgs = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(DiffCodeBlock),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.color)
          .toList();
      expect(lineBgs, contains(light.success.withValues(alpha: 0.08)));
      expect(lineBgs, contains(light.danger.withValues(alpha: 0.08)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('消息正文的普通语言代码块：深色 CodeBlockView', (tester) async {
      await tester.pumpWidget(
        _wrap(ChatTextPart(content: '```dart\nvoid main() {}\n```')),
      );
      expect(find.byType(CodeBlockView), findsOneWidget);
      expect(find.byType(DiffCodeBlock), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('HighlightText', () {
    const code = '// comment\nvoid main() {\n  print("hi");\n}';

    testWidgets('通用语法高亮：注释/关键字/字符串', (tester) async {
      await tester.pumpWidget(
        _wrap(HighlightText(text: code, language: langDart)),
      );
      final segs = _segments(
        tester.widget<SelectableText>(find.byType(SelectableText)).textSpan!,
      );
      // 注释：次级色 + 斜体
      expect(
        _segFor(segs, '// comment').$2!.color,
        AppColors.light.textSecondary,
      );
      expect(
        _segFor(segs, '// comment').$2!.fontStyle,
        FontStyle.italic,
      );
      // 关键字：警示色
      expect(_segFor(segs, 'void').$2!.color, AppColors.light.warning);
      // 字符串：成功色
      expect(_segFor(segs, '"hi"').$2!.color, AppColors.light.success);
      // 可选中、无背景
      expect(find.byType(SelectableText), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HighlightText),
          matching: find.byType(Container),
        ),
        findsNothing,
      );
    });

    testWidgets('横向滚动模式', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HighlightText(
            text: code,
            language: langDart,
            horizontalScroll: true,
          ),
        ),
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
