import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:streamdown/streamdown.dart';

/// Pump a [Streamdown.text] inside a [MaterialApp] scaffold.
Future<void> pumpStatic(
  WidgetTester tester,
  String markdown, {
  void Function(Uri uri)? onLinkTap,
  bool selectable = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Streamdown.text(
          markdown,
          onLinkTap: onLinkTap,
          selectable: selectable,
        ),
      ),
    ),
  );
}

void main() {
  group('Streamdown — block-level rendering', () {
    testWidgets('renders a single H1', (tester) async {
      await pumpStatic(tester, '# Hello\n');
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('renders all 6 heading levels', (tester) async {
      await pumpStatic(tester, '# A\n## B\n### C\n#### D\n##### E\n###### F\n');
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('E'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
    });

    testWidgets('renders a paragraph', (tester) async {
      await pumpStatic(tester, 'Hello, world.\n');
      expect(find.textContaining('Hello, world.'), findsWidgets);
    });

    testWidgets('renders horizontal rule as a Divider', (tester) async {
      await pumpStatic(tester, '---\n');
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('renders a blockquote', (tester) async {
      await pumpStatic(tester, '> quoted text\n');
      expect(find.textContaining('quoted text'), findsWidgets);
    });

    testWidgets('renders an unordered list', (tester) async {
      await pumpStatic(tester, '- one\n- two\n- three\n');
      expect(find.textContaining('one'), findsWidgets);
      expect(find.textContaining('two'), findsWidgets);
      expect(find.textContaining('three'), findsWidgets);
      // Bullet markers
      expect(find.text('•'), findsNWidgets(3));
    });

    testWidgets('renders an ordered list with numbered markers', (
      tester,
    ) async {
      await pumpStatic(tester, '1. first\n2. second\n');
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
    });

    testWidgets('renders task list with checkbox glyphs', (tester) async {
      await pumpStatic(tester, '- [ ] todo\n- [x] done\n');
      expect(find.text('☐'), findsOneWidget);
      expect(find.text('☑'), findsOneWidget);
    });

    testWidgets('renders a fenced code block', (tester) async {
      await pumpStatic(tester, '```dart\nprint(42);\n```\n');
      expect(
        find.textContaining('print(42);', findRichText: true),
        findsWidgets,
      );
    });

    testWidgets('renders a GFM table', (tester) async {
      await pumpStatic(tester, '| h1 | h2 |\n|----|----|\n| a  | b  |\n');
      expect(find.text('h1'), findsOneWidget);
      expect(find.text('h2'), findsOneWidget);
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
    });
  });

  group('Streamdown — inline formatting', () {
    testWidgets('inline code span', (tester) async {
      await pumpStatic(tester, 'use `printf` for output\n');
      // The code span text should appear as part of a TextSpan.
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      expect(richText.text.toPlainText(), contains('printf'));
    });

    testWidgets('bold text', (tester) async {
      await pumpStatic(tester, 'a **bold** word\n');
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final plain = richText.text.toPlainText();
      expect(plain, contains('bold'));
      // The '**' delimiters should not appear in the rendered text.
      expect(plain, isNot(contains('**')));
    });

    testWidgets('italic text', (tester) async {
      await pumpStatic(tester, 'a *italic* word\n');
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      expect(richText.text.toPlainText(), contains('italic'));
      expect(richText.text.toPlainText(), isNot(contains('*italic*')));
    });

    testWidgets('strikethrough', (tester) async {
      await pumpStatic(tester, 'a ~~gone~~ word\n');
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      expect(richText.text.toPlainText(), contains('gone'));
      expect(richText.text.toPlainText(), isNot(contains('~~')));
    });

    testWidgets('link tap fires callback', (tester) async {
      Uri? tapped;
      await pumpStatic(
        tester,
        'visit [the site](https://example.com)\n',
        onLinkTap: (uri) => tapped = uri,
      );
      // Find the link text and tap on it.
      final finder = find.textContaining('the site');
      expect(finder, findsWidgets);
      // Tap directly using SelectableText: tap on the surrounding container.
      await tester.tap(find.byType(SelectionArea).first);
      // Selection tap may not fire link recognizer; manual recognizer fires
      // via the gesture system. We verify by exercising the recognizer
      // directly via the RichText's TextSpan tree.
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      // Walk spans to find the link span and invoke its recognizer.
      void visit(InlineSpan span) {
        if (span is TextSpan) {
          if (span.recognizer is TapGestureRecognizer && tapped == null) {
            (span.recognizer! as TapGestureRecognizer).onTap?.call();
          }
          span.children?.forEach(visit);
        }
      }

      visit(richText.text);
      expect(tapped, Uri.parse('https://example.com'));
    });

    testWidgets('autolink renders the URL text', (tester) async {
      await pumpStatic(tester, 'see <https://example.com> for more\n');
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      expect(richText.text.toPlainText(), contains('https://example.com'));
    });
  });

  group('Streamdown — selection', () {
    testWidgets('SelectionArea wraps content when selectable=true', (
      tester,
    ) async {
      await pumpStatic(tester, 'paragraph\n');
      expect(find.byType(SelectionArea), findsOneWidget);
    });

    testWidgets('No SelectionArea when selectable=false', (tester) async {
      await pumpStatic(tester, 'paragraph\n', selectable: false);
      expect(find.byType(SelectionArea), findsNothing);
    });
  });

  group('Streamdown — streaming stability', () {
    testWidgets(
      'closed widgets persist across chunk feeds (no element churn)',
      (tester) async {
        final controller = StreamController<String>();
        addTearDown(controller.close);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Streamdown(stream: controller.stream)),
          ),
        );

        controller.add('# First heading\n\n');
        await tester.pump();
        await tester.pump();
        expect(find.text('First heading'), findsOneWidget);
        final firstElement = tester.element(find.text('First heading'));

        // Add more content — the first heading should not be torn down.
        controller.add('Some paragraph text.\n\n');
        await tester.pump();
        await tester.pump();
        controller.add('## Second heading\n\n');
        await tester.pump();
        await tester.pump();
        controller.add('Even more text after second.\n');
        await tester.pump();
        await tester.pump();

        expect(find.text('First heading'), findsOneWidget);
        expect(find.text('Second heading'), findsOneWidget);
        final firstElementAfter = tester.element(find.text('First heading'));
        expect(
          identical(firstElement, firstElementAfter),
          isTrue,
          reason: 'first heading element should be preserved across feeds',
        );
      },
    );

    testWidgets('stream complete finalizes open paragraph', (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Streamdown(stream: controller.stream)),
        ),
      );

      controller.add('hello world\n');
      await tester.pump();
      expect(find.textContaining('hello world'), findsWidgets);

      // Don't await the close — in flutter_test's fake-async zone, the close
      // future only resolves after the subscription's onDone runs, which
      // requires another pump. Awaiting here would deadlock.
      unawaited(controller.close());
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('hello world'), findsWidgets);
    });
  });
}
