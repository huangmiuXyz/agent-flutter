import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:streamdown/streamdown.dart';

Future<void> pumpStatic(
  WidgetTester tester,
  String md, {
  void Function(Uri uri)? onLinkTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Streamdown.text(md, onLinkTap: onLinkTap)),
    ),
  );
}

/// Walk every RichText in the widget tree to find the first TextSpan whose
/// text matches [needle]. Returns its resolved TextAlign (from the
/// containing RichText), or null if not found.
TextAlign? findTextAlignOf(WidgetTester tester, String needle) {
  final richTexts = tester.widgetList<RichText>(find.byType(RichText));
  for (final rt in richTexts) {
    if (rt.text.toPlainText().contains(needle)) {
      return rt.textAlign;
    }
  }
  return null;
}

void main() {
  group('Streamdown — table cell alignment', () {
    testWidgets('left / center / right alignments are applied', (tester) async {
      const md = '| L | C | R |\n|:--|:--:|--:|\n| left | center | right |\n';
      await pumpStatic(tester, md);

      expect(find.byType(Table), findsOneWidget);
      expect(findTextAlignOf(tester, 'left'), TextAlign.left);
      expect(findTextAlignOf(tester, 'center'), TextAlign.center);
      expect(findTextAlignOf(tester, 'right'), TextAlign.right);
    });

    testWidgets('no alignment marker → TextAlign.start', (tester) async {
      const md = '| a |\n|---|\n| body |\n';
      await pumpStatic(tester, md);
      expect(findTextAlignOf(tester, 'body'), TextAlign.start);
    });
  });

  group('Streamdown — inline markdown in cells', () {
    testWidgets('bold delimiters are stripped and the text remains', (
      tester,
    ) async {
      const md = '| col |\n|-----|\n| **bold cell** |\n';
      await pumpStatic(tester, md);

      // Find the cell's RichText and verify the rendered plain-text drops `**`.
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final cellText = richTexts
          .map((rt) => rt.text.toPlainText())
          .firstWhere((t) => t.contains('bold cell'), orElse: () => '');
      expect(cellText, isNot(contains('**')));
      expect(cellText, contains('bold cell'));
    });

    testWidgets('link in a cell fires onLinkTap when tapped', (tester) async {
      Uri? tapped;
      const md =
          '| col |\n|-----|\n| visit [docs](https://example.com/docs) |\n';
      await pumpStatic(tester, md, onLinkTap: (uri) => tapped = uri);

      // Walk RichText spans to find the link recognizer and invoke it.
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      RichText? cell;
      for (final rt in richTexts) {
        if (rt.text.toPlainText().contains('docs')) {
          cell = rt;
          break;
        }
      }
      expect(cell, isNotNull);

      void visit(InlineSpan span) {
        if (span is TextSpan) {
          if (span.recognizer is TapGestureRecognizer && tapped == null) {
            (span.recognizer! as TapGestureRecognizer).onTap?.call();
          }
          span.children?.forEach(visit);
        }
      }

      visit(cell!.text);
      expect(tapped, Uri.parse('https://example.com/docs'));
    });

    testWidgets('inline code in a cell renders code span content', (
      tester,
    ) async {
      const md = '| col |\n|-----|\n| use `printf` to log |\n';
      await pumpStatic(tester, md);

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final cellText = richTexts
          .map((rt) => rt.text.toPlainText())
          .firstWhere((t) => t.contains('printf'), orElse: () => '');
      expect(cellText, contains('printf'));
      // The backticks should not appear in the rendered text.
      expect(cellText, isNot(contains('`printf`')));
    });
  });

  group('Streamdown — table horizontal scroll', () {
    testWidgets('wide table is wrapped in a SingleChildScrollView', (
      tester,
    ) async {
      const md = '| a | b | c |\n|---|---|---|\n| 1 | 2 | 3 |\n';
      await pumpStatic(tester, md);

      // Find the ScrollView that hosts the Table.
      final tableFinder = find.byType(Table);
      expect(tableFinder, findsOneWidget);
      final scrollView = find.ancestor(
        of: tableFinder,
        matching: find.byType(SingleChildScrollView),
      );
      expect(scrollView, findsWidgets);
    });
  });

  group('Streamdown — table streaming stability', () {
    testWidgets('table grows row-by-row as chunks stream in', (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Streamdown(stream: controller.stream)),
        ),
      );

      controller.add('| h |\n|---|\n| r1 |\n');
      await tester.pump();
      await tester.pump();
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('r1'), findsOneWidget);

      // Element should persist when the next chunk just adds a row.
      final initialElement = tester.element(find.byType(Table));

      controller.add('| r2 |\n');
      await tester.pump();
      await tester.pump();
      expect(find.text('r2'), findsOneWidget);

      controller.add('| r3 |\n');
      await tester.pump();
      await tester.pump();
      expect(find.text('r3'), findsOneWidget);

      final afterElement = tester.element(find.byType(Table));
      expect(
        identical(initialElement, afterElement),
        isTrue,
        reason:
            'Table element should be preserved across body-row append feeds',
      );
    });
  });
}
