import 'package:flutter_test/flutter_test.dart';
import 'package:streamdown/src/parser/token.dart';
import 'package:streamdown/src/parser/tokenizer.dart';

/// Helper: tokenize a full string at once via a fresh Tokenizer.
List<Token> tokenizeAll(String input) {
  final t = Tokenizer();
  final tokens = <Token>[...t.feed(input), ...t.complete()];
  return tokens;
}

/// Helper: tokenize the same input via repeated 1-character feeds —
/// must produce the same final token sequence.
List<Token> tokenizeChunked(String input, {int chunkSize = 1}) {
  final t = Tokenizer();
  final out = <Token>[];
  for (var i = 0; i < input.length; i += chunkSize) {
    final end = (i + chunkSize) > input.length ? input.length : i + chunkSize;
    out.addAll(t.feed(input.substring(i, end)));
  }
  out.addAll(t.complete());
  return out;
}

void main() {
  group('Tokenizer — block-level', () {
    test('emits nothing for empty input', () {
      expect(tokenizeAll(''), isEmpty);
    });

    test('single blank line', () {
      expect(tokenizeAll('\n'), const [BlankLineToken()]);
    });

    test('ATX heading level 1', () {
      expect(tokenizeAll('# Hello\n'), const [HeadingToken(1, 'Hello')]);
    });

    test('ATX heading level 6', () {
      expect(tokenizeAll('###### Six\n'), const [HeadingToken(6, 'Six')]);
    });

    test('ATX heading 7 hashes is not a heading', () {
      // Per CommonMark, 7+ hashes is not an ATX heading.
      final tokens = tokenizeAll('####### Nope\n');
      expect(tokens.length, 1);
      expect(tokens.first, isA<TextLineToken>());
    });

    test('ATX heading with trailing closing #s', () {
      expect(tokenizeAll('## Title ##\n'), const [HeadingToken(2, 'Title')]);
    });

    test('ATX heading without text', () {
      expect(tokenizeAll('#\n'), const [HeadingToken(1, '')]);
    });

    test('horizontal rule with dashes', () {
      expect(tokenizeAll('---\n'), const [HorizontalRuleToken()]);
    });

    test('horizontal rule with asterisks', () {
      expect(tokenizeAll('***\n'), const [HorizontalRuleToken()]);
    });

    test('horizontal rule with underscores', () {
      expect(tokenizeAll('___\n'), const [HorizontalRuleToken()]);
    });

    test('horizontal rule with spaces between markers', () {
      expect(tokenizeAll('- - -\n'), const [HorizontalRuleToken()]);
    });

    test('horizontal rule needs >=3 markers', () {
      final tokens = tokenizeAll('--\n');
      expect(tokens.length, 1);
      expect(tokens.first, isA<TextLineToken>());
    });

    test('paragraph text', () {
      expect(tokenizeAll('Hello world\n'), const [
        TextLineToken('Hello world'),
      ]);
    });

    test('multi-line paragraph keeps each line separate', () {
      final tokens = tokenizeAll('Line one\nLine two\n');
      expect(tokens, const [
        TextLineToken('Line one'),
        TextLineToken('Line two'),
      ]);
    });

    test('blockquote single depth', () {
      expect(tokenizeAll('> quoted\n'), const [
        BlockquoteMarkerToken(1),
        TextLineToken('quoted'),
      ]);
    });

    test('blockquote nested', () {
      expect(tokenizeAll('>> deep\n'), const [
        BlockquoteMarkerToken(2),
        TextLineToken('deep'),
      ]);
    });

    test('blockquote with no following content', () {
      expect(tokenizeAll('>\n'), const [BlockquoteMarkerToken(1)]);
    });

    test('unordered list marker -', () {
      expect(tokenizeAll('- item\n'), const [
        ListMarkerToken(indent: 0, ordered: false),
        TextLineToken('item'),
      ]);
    });

    test('unordered list marker *', () {
      expect(tokenizeAll('* item\n'), const [
        ListMarkerToken(indent: 0, ordered: false),
        TextLineToken('item'),
      ]);
    });

    test('unordered list marker + with indent', () {
      expect(tokenizeAll('  + item\n'), const [
        ListMarkerToken(indent: 2, ordered: false),
        TextLineToken('item'),
      ]);
    });

    test('ordered list marker 1.', () {
      expect(tokenizeAll('1. first\n'), const [
        ListMarkerToken(indent: 0, ordered: true, number: 1),
        TextLineToken('first'),
      ]);
    });

    test('ordered list marker 42)', () {
      expect(tokenizeAll('42) forty-two\n'), const [
        ListMarkerToken(indent: 0, ordered: true, number: 42),
        TextLineToken('forty-two'),
      ]);
    });

    test('task list unchecked', () {
      expect(tokenizeAll('- [ ] todo\n'), const [
        ListMarkerToken(indent: 0, ordered: false, isTask: true),
        TextLineToken('todo'),
      ]);
    });

    test('task list checked (x)', () {
      expect(tokenizeAll('- [x] done\n'), const [
        ListMarkerToken(
          indent: 0,
          ordered: false,
          isTask: true,
          isChecked: true,
        ),
        TextLineToken('done'),
      ]);
    });

    test('task list checked (X)', () {
      expect(tokenizeAll('- [X] done\n'), const [
        ListMarkerToken(
          indent: 0,
          ordered: false,
          isTask: true,
          isChecked: true,
        ),
        TextLineToken('done'),
      ]);
    });

    test('fence open with language', () {
      final tokens = tokenizeAll('```dart\n');
      expect(tokens.length, 1);
      expect(
        tokens.first,
        const FenceOpenToken(fenceChar: '`', fenceLength: 3, language: 'dart'),
      );
    });

    test('fence open without language', () {
      expect(
        tokenizeAll('```\n').first,
        const FenceOpenToken(fenceChar: '`', fenceLength: 3),
      );
    });

    test('fence with longer than 3 backticks', () {
      expect(
        tokenizeAll('````dart\n').first,
        const FenceOpenToken(fenceChar: '`', fenceLength: 4, language: 'dart'),
      );
    });

    test('tilde fence', () {
      expect(
        tokenizeAll('~~~js\n').first,
        const FenceOpenToken(fenceChar: '~', fenceLength: 3, language: 'js'),
      );
    });

    test('complete fenced code block', () {
      final tokens = tokenizeAll('```dart\nprint(42);\n```\n');
      expect(tokens, const [
        FenceOpenToken(fenceChar: '`', fenceLength: 3, language: 'dart'),
        CodeLineToken('print(42);'),
        FenceCloseToken(),
      ]);
    });

    test('code lines inside fence keep verbatim content', () {
      final tokens = tokenizeAll('```\n# not a heading\n> not a quote\n```\n');
      expect(tokens, const [
        FenceOpenToken(fenceChar: '`', fenceLength: 3),
        CodeLineToken('# not a heading'),
        CodeLineToken('> not a quote'),
        FenceCloseToken(),
      ]);
    });

    test('unclosed fence: trailing lines remain code', () {
      final tokens = tokenizeAll('```\nlets go\n');
      expect(tokens, const [
        FenceOpenToken(fenceChar: '`', fenceLength: 3),
        CodeLineToken('lets go'),
      ]);
    });

    test('closing fence requires >= open length', () {
      final tokens = tokenizeAll('````\ncode\n```\nmore\n````\n');
      expect(tokens, const [
        FenceOpenToken(fenceChar: '`', fenceLength: 4),
        CodeLineToken('code'),
        CodeLineToken('```'),
        CodeLineToken('more'),
        FenceCloseToken(),
      ]);
    });

    test('table row two cells', () {
      expect(tokenizeAll('| a | b |\n').first, const TableRowToken(['a', 'b']));
    });

    test('table row without outer pipes', () {
      expect(tokenizeAll('a | b\n').first, const TableRowToken(['a', 'b']));
    });

    test('table separator simple', () {
      expect(
        tokenizeAll('|---|---|\n').first,
        const TableSeparatorToken([TableAlignment.none, TableAlignment.none]),
      );
    });

    test('table separator with alignments', () {
      expect(
        tokenizeAll('|:--|:--:|--:|\n').first,
        const TableSeparatorToken([
          TableAlignment.left,
          TableAlignment.center,
          TableAlignment.right,
        ]),
      );
    });

    test('table cells with escaped pipe', () {
      expect(
        tokenizeAll(
          r'| a \| b | c |'
          '\n',
        ).first,
        const TableRowToken(['a | b', 'c']),
      );
    });

    test('CRLF line endings stripped', () {
      expect(tokenizeAll('# Hi\r\n'), const [HeadingToken(1, 'Hi')]);
    });

    test('pendingLine exposes mid-line buffer', () {
      final t = Tokenizer();
      t.feed('# Heading');
      expect(t.pendingLine, '# Heading');
      t.feed('\n');
      expect(t.pendingLine, '');
    });

    test('insideFence flips on fence open and back on close', () {
      final t = Tokenizer();
      t.feed('```\n');
      expect(t.insideFence, isTrue);
      t.feed('code\n```\n');
      expect(t.insideFence, isFalse);
    });

    test('complete() flushes a trailing unterminated line', () {
      final t = Tokenizer();
      t.feed('# Heading');
      expect(t.feed(''), isEmpty);
      final tokens = t.complete();
      expect(tokens, const [HeadingToken(1, 'Heading')]);
    });
  });

  group('Tokenizer — chunked vs whole equivalence', () {
    final samples = <String>[
      '# Hello\nWorld\n',
      '```dart\nprint(1);\nprint(2);\n```\n',
      '- one\n- two\n- three\n',
      '> a quote\n> still\n\nback to paragraph\n',
      '| h1 | h2 |\n|----|----|\n| a  | b  |\n',
      '1. first\n2. second\n3. third\n',
      '## A\n\nSome **bold** text\n\n---\n\nMore\n',
      '   ```\n   indented fence\n   ```\n',
      '- [ ] todo\n- [x] done\n',
      '',
    ];

    for (var idx = 0; idx < samples.length; idx++) {
      test('sample $idx — char-by-char == whole feed', () {
        final s = samples[idx];
        final whole = tokenizeAll(s);
        final chunked = tokenizeChunked(s);
        expect(chunked, whole);
      });

      test('sample $idx — 3-char chunks == whole feed', () {
        final s = samples[idx];
        final whole = tokenizeAll(s);
        final chunked = tokenizeChunked(s, chunkSize: 3);
        expect(chunked, whole);
      });

      test('sample $idx — 17-char chunks == whole feed', () {
        final s = samples[idx];
        final whole = tokenizeAll(s);
        final chunked = tokenizeChunked(s, chunkSize: 17);
        expect(chunked, whole);
      });
    }
  });

  group('Tokenizer — append-only invariant', () {
    test(
      'feeding more does not retroactively change already-emitted tokens',
      () {
        final t = Tokenizer();
        final first = t.feed('# Heading\nSome text\n');
        expect(first.length, 2);
        final snapshot = List<Token>.from(first);
        t.feed('\n```dart\ncode\n```\n');
        expect(first, equals(snapshot));
      },
    );

    test('linear performance on large input — no quadratic blowup', () {
      // Build a 10k-line markdown doc and feed it character by character.
      // The whole thing should complete in well under a second on any
      // modern machine. Token count should equal the line count.
      final sb = StringBuffer();
      for (var i = 0; i < 10000; i++) {
        sb.writeln('paragraph line $i');
      }
      final s = sb.toString();

      final stopwatch = Stopwatch()..start();
      final t = Tokenizer();
      final tokens = <Token>[];
      for (var i = 0; i < s.length; i++) {
        tokens.addAll(t.feed(s[i]));
      }
      tokens.addAll(t.complete());
      stopwatch.stop();

      expect(tokens.length, 10000);
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason:
            'Char-by-char tokenization of 10k lines took ${stopwatch.elapsedMilliseconds}ms — '
            'suspect quadratic behavior.',
      );
    });
  });
}
