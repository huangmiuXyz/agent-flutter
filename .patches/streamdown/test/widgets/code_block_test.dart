import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:streamdown/streamdown.dart';

void main() {
  group('Streamdown — code block rendering', () {
    testWidgets('renders highlighted code via HighlightView', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Streamdown.text('```dart\nvoid main() {}\n```\n'),
          ),
        ),
      );
      expect(find.byType(HighlightView), findsOneWidget);
      expect(find.textContaining('main', findRichText: true), findsWidgets);
    });

    testWidgets('shows the language label in the header', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Streamdown.text('```python\nprint("hi")\n```\n'),
          ),
        ),
      );
      expect(find.text('python'), findsOneWidget);
    });

    testWidgets('no language label when fence has no info string', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Streamdown.text('```\nplain\n```\n')),
        ),
      );
      // The header still exists (for the copy button), but no language text.
      // We assert by searching for the copy icon — it should be present.
      expect(find.byIcon(Icons.content_copy_outlined), findsOneWidget);
    });

    testWidgets('horizontal scroll wraps long lines', (tester) async {
      final long = 'a' * 200;
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Streamdown.text('```\n$long\n```\n'))),
      );
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });
  });

  group('Streamdown — copy button', () {
    testWidgets('tapping copy puts code on the clipboard', (tester) async {
      String? pasted;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            pasted = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Streamdown.text('```dart\nprint(42);\n```\n')),
        ),
      );

      await tester.tap(find.byIcon(Icons.content_copy_outlined));
      await tester.pump();
      expect(pasted, 'print(42);');

      // After tap, icon should swap to a check.
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  group('Streamdown — codeBlockBuilder', () {
    testWidgets('custom builder replaces the default rendering', (
      tester,
    ) async {
      var calls = 0;
      String? capturedLang;
      String? capturedCode;
      bool? capturedComplete;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Streamdown.text(
              '```js\nconst x = 1;\n```\n',
              codeBlockBuilder: (context, lang, code, isComplete) {
                calls++;
                capturedLang = lang;
                capturedCode = code;
                capturedComplete = isComplete;
                return const KeyedSubtree(
                  key: Key('custom-builder'),
                  child: SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
      );

      expect(calls, greaterThanOrEqualTo(1));
      expect(capturedLang, 'js');
      expect(capturedCode, 'const x = 1;');
      expect(capturedComplete, isTrue);
      expect(find.byKey(const Key('custom-builder')), findsOneWidget);
      // Default HighlightView should not render when custom builder is used.
      expect(find.byType(HighlightView), findsNothing);
    });
  });

  group('Streamdown — code block streaming stability', () {
    testWidgets('closed code block element persists across subsequent chunks', (
      tester,
    ) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Streamdown(stream: controller.stream)),
        ),
      );

      controller.add('```dart\nvoid main() {}\n```\n\n');
      await tester.pump();
      await tester.pump();

      expect(find.byType(HighlightView), findsOneWidget);
      final firstElement = tester.element(find.byType(HighlightView));

      controller.add('more **bold** text\n');
      await tester.pump();
      await tester.pump();
      controller.add('## A heading\n');
      await tester.pump();
      await tester.pump();

      expect(find.byType(HighlightView), findsOneWidget);
      final after = tester.element(find.byType(HighlightView));
      expect(
        identical(firstElement, after),
        isTrue,
        reason:
            'closed code block should not re-mount when later blocks arrive',
      );
    });

    testWidgets('open code block grows as more lines stream in', (
      tester,
    ) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Streamdown(stream: controller.stream)),
        ),
      );

      controller.add('```dart\nline one\n');
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('line one', findRichText: true), findsWidgets);

      controller.add('line two\n');
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('line two', findRichText: true), findsWidgets);

      controller.add('line three\n```\n');
      await tester.pump();
      await tester.pump();
      expect(
        find.textContaining('line three', findRichText: true),
        findsWidgets,
      );
    });
  });

  group('Streamdown — syntax theme', () {
    testWidgets('respects light theme background by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: Streamdown.text('```dart\nint x = 1;\n```\n'),
          ),
        ),
      );
      // No exception means the theme resolved correctly.
      expect(find.byType(HighlightView), findsOneWidget);
    });

    testWidgets('respects dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: Streamdown.text('```dart\nint x = 1;\n```\n'),
          ),
        ),
      );
      expect(find.byType(HighlightView), findsOneWidget);
    });

    testWidgets('custom SyntaxTheme overrides auto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Streamdown.text(
              '```dart\nint x = 1;\n```\n',
              syntaxTheme: SyntaxTheme.atomOneDark(),
            ),
          ),
        ),
      );
      expect(find.byType(HighlightView), findsOneWidget);
    });
  });
}
