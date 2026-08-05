import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:streamdown/src/parser/inline_tokenizer.dart';
import 'package:streamdown/src/parser/token.dart';
import 'package:streamdown/streamdown.dart';

void main() {
  group('Phase 6 — bare URL autolinking', () {
    test('bare https URL emits AutolinkToken', () {
      final tokens = InlineTokenizer.tokenize(
        'visit https://example.com today',
      );
      final autolinks = tokens.whereType<AutolinkToken>().toList();
      expect(autolinks, hasLength(1));
      expect(autolinks.first.url, 'https://example.com');
    });

    test('bare http URL emits AutolinkToken', () {
      final tokens = InlineTokenizer.tokenize('http://x.com works');
      expect(tokens.whereType<AutolinkToken>().single.url, 'http://x.com');
    });

    test('trailing period is stripped', () {
      final tokens = InlineTokenizer.tokenize(
        'See https://example.com. Then continue.',
      );
      expect(
        tokens.whereType<AutolinkToken>().single.url,
        'https://example.com',
      );
    });

    test('trailing punctuation cluster ").," is stripped', () {
      final tokens = InlineTokenizer.tokenize('(see https://x.com),');
      expect(tokens.whereType<AutolinkToken>().single.url, 'https://x.com');
    });

    test('URL inside angle brackets still works via classic autolink', () {
      final tokens = InlineTokenizer.tokenize('<https://classic.com>');
      expect(
        tokens.whereType<AutolinkToken>().single.url,
        'https://classic.com',
      );
    });
  });

  group('Phase 6 — image rendering', () {
    testWidgets('image syntax produces an Image widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Streamdown.text('![alt text](https://example.com/img.png)\n'),
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('failing image falls back to [alt] text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Streamdown.text('![the alt](https://invalid.invalid/x.png)'),
          ),
        ),
      );
      // Wait for the network image to fail (in widget tests it errors out).
      await tester.pumpAndSettle(const Duration(seconds: 1));
      // Either the placeholder text or the alt-fallback should appear.
      expect(find.textContaining('the alt', findRichText: true), findsWidgets);
    });
  });

  group('Phase 6 — errorBuilder', () {
    testWidgets('stream errors trigger errorBuilder', (tester) async {
      final controller = StreamController<String>();
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });

      Object? capturedError;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Streamdown(
              stream: controller.stream,
              errorBuilder: (context, error, stack) {
                capturedError = error;
                return const KeyedSubtree(
                  key: Key('error-fallback'),
                  child: Text('error happened'),
                );
              },
            ),
          ),
        ),
      );

      controller.add('# Hello\n');
      await tester.pump();
      expect(find.text('Hello'), findsOneWidget);

      controller.addError('boom');
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('error-fallback')), findsOneWidget);
      expect(capturedError, 'boom');
    });

    testWidgets('without errorBuilder, errors are silently swallowed', (
      tester,
    ) async {
      final controller = StreamController<String>();
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Streamdown(stream: controller.stream)),
        ),
      );

      controller.add('# Hello\n');
      await tester.pump();
      expect(find.text('Hello'), findsOneWidget);

      controller.addError('boom');
      await tester.pump();
      // No crash; heading is still visible.
      expect(find.text('Hello'), findsOneWidget);
    });
  });

  group('Phase 6 — LaTeX math', () {
    test(r'inline $..$ produces MathToken when latex enabled', () {
      final tokens = InlineTokenizer.tokenize(r'E=$mc^2$ classic', latex: true);
      final math = tokens.whereType<MathToken>().toList();
      expect(math, hasLength(1));
      expect(math.first.tex, 'mc^2');
      expect(math.first.isBlock, isFalse);
    });

    test('block \$\$..\$\$ produces block MathToken when latex enabled', () {
      final tokens = InlineTokenizer.tokenize(r'see $$E = mc^2$$', latex: true);
      final math = tokens.whereType<MathToken>().single;
      expect(math.tex, 'E = mc^2');
      expect(math.isBlock, isTrue);
    });

    test('dollar amounts are NOT math when latex is disabled', () {
      final tokens = InlineTokenizer.tokenize(r'Price is $10 and $20');
      expect(tokens.whereType<MathToken>(), isEmpty);
    });

    test(r'inline math requires non-space adjacent to opening $', () {
      final tokens = InlineTokenizer.tokenize(r'$ not math $', latex: true);
      expect(tokens.whereType<MathToken>(), isEmpty);
    });
  });
}
