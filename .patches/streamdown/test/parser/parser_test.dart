import 'package:flutter_test/flutter_test.dart';
import 'package:streamdown/src/parser/ast.dart';
import 'package:streamdown/src/parser/parser.dart';
import 'package:streamdown/src/parser/tokenizer.dart';

/// Tokenize + parse [input] all at once.
DocumentNode parseAll(String input) {
  final tok = Tokenizer();
  final p = Parser();
  p.feed(tok.feed(input));
  p.feed(tok.complete());
  p.complete();
  return p.document;
}

/// Tokenize + parse in fixed-size chunks.
DocumentNode parseChunked(String input, {int chunkSize = 1}) {
  final tok = Tokenizer();
  final p = Parser();
  for (var i = 0; i < input.length; i += chunkSize) {
    final end = (i + chunkSize) > input.length ? input.length : i + chunkSize;
    p.feed(tok.feed(input.substring(i, end)));
  }
  p.feed(tok.complete());
  p.complete();
  return p.document;
}

/// Produce a deterministic, readable string snapshot of an AST.
///
/// Includes node type, key fields, and complete-state. Excludes IDs (since
/// they're position-dependent and would make snapshots fragile to reordering).
String snapshot(AstNode node, {int depth = 0}) {
  final indent = '  ' * depth;
  final sb = StringBuffer();

  switch (node) {
    case DocumentNode(:final children):
      sb.write('${indent}Doc(${children.length})');
      for (final c in children) {
        sb.write('\n');
        sb.write(snapshot(c, depth: depth + 1));
      }

    case HeadingNode(:final level, :final text, :final isComplete):
      sb.write('${indent}H$level(${_q(text)})');
      if (!isComplete) sb.write(' OPEN');

    case ParagraphNode(:final text, :final isComplete):
      sb.write('${indent}P(${_q(text)})');
      if (!isComplete) sb.write(' OPEN');

    case CodeBlockNode(:final language, :final lines, :final isComplete):
      sb.write('${indent}Code(lang=${_q(language)}, ${lines.length}L)');
      if (!isComplete) sb.write(' OPEN');
      for (final l in lines) {
        sb.write('\n$indent  > ${_q(l)}');
      }

    case BlockquoteNode(:final depth, :final children, :final isComplete):
      sb.write('${indent}Q(d=$depth, ${children.length})');
      if (!isComplete) sb.write(' OPEN');
      for (final c in children) {
        sb.write('\n');
        sb.write(snapshot(c, depth: depth + 1));
      }

    case ListNode(:final ordered, :final items, :final isComplete):
      sb.write('${indent}List(${ordered ? "ol" : "ul"}, ${items.length})');
      if (!isComplete) sb.write(' OPEN');
      for (final i in items) {
        sb.write('\n');
        sb.write(snapshot(i, depth: depth + 1));
      }

    case ListItemNode(
      :final isTask,
      :final isChecked,
      :final children,
      :final isComplete,
    ):
      final task = isTask ? '[${isChecked ? "x" : " "}]' : '';
      sb.write('${indent}Item$task(${children.length})');
      if (!isComplete) sb.write(' OPEN');
      for (final c in children) {
        sb.write('\n');
        sb.write(snapshot(c, depth: depth + 1));
      }

    case TableNode(
      :final headers,
      :final alignments,
      :final rows,
      :final isComplete,
    ):
      sb.write('${indent}Table(h=${headers.length}, ${rows.length}R)');
      if (!isComplete) sb.write(' OPEN');
      sb.write('\n$indent  H: $headers');
      sb.write('\n$indent  A: ${alignments.map((a) => a.name).join(",")}');
      for (final r in rows) {
        sb.write('\n$indent  R: $r');
      }

    case HorizontalRuleNode():
      sb.write('${indent}HR');
  }

  return sb.toString();
}

String _q(String? s) => s == null ? 'null' : '"$s"';

void main() {
  group('Parser — block types', () {
    test('empty input → empty document', () {
      final doc = parseAll('');
      expect(doc.children, isEmpty);
      expect(doc.isComplete, isTrue);
    });

    test('single H1', () {
      expect(snapshot(parseAll('# Hello\n')), 'Doc(1)\n  H1("Hello")');
    });

    test('all 6 heading levels', () {
      const md = '# A\n## B\n### C\n#### D\n##### E\n###### F\n';
      expect(
        snapshot(parseAll(md)),
        'Doc(6)\n  H1("A")\n  H2("B")\n  H3("C")\n  H4("D")\n  H5("E")\n  H6("F")',
      );
    });

    test('horizontal rule with dashes', () {
      expect(snapshot(parseAll('---\n')), 'Doc(1)\n  HR');
    });

    test('horizontal rule with asterisks', () {
      expect(snapshot(parseAll('***\n')), 'Doc(1)\n  HR');
    });

    test('single-line paragraph', () {
      expect(snapshot(parseAll('Hello world\n')), 'Doc(1)\n  P("Hello world")');
    });

    test('multi-line paragraph joins with newline (soft-break)', () {
      expect(snapshot(parseAll('a\nb\nc\n')), 'Doc(1)\n  P("a\nb\nc")');
    });

    test('two paragraphs separated by blank line', () {
      expect(
        snapshot(parseAll('first\n\nsecond\n')),
        'Doc(2)\n  P("first")\n  P("second")',
      );
    });

    test('complete fenced code block', () {
      const md = '```dart\nprint(42);\n```\n';
      expect(
        snapshot(parseAll(md)),
        'Doc(1)\n  Code(lang="dart", 1L)\n    > "print(42);"',
      );
    });

    test('code block without language', () {
      expect(
        snapshot(parseAll('```\nfoo\n```\n')),
        'Doc(1)\n  Code(lang=null, 1L)\n    > "foo"',
      );
    });

    test('code block multiple lines', () {
      const md = '```\nline1\nline2\nline3\n```\n';
      expect(
        snapshot(parseAll(md)),
        'Doc(1)\n  Code(lang=null, 3L)\n    > "line1"\n    > "line2"\n    > "line3"',
      );
    });

    test('unclosed fenced code block stays OPEN', () {
      const md = '```dart\nprint(1);\n';
      expect(
        snapshot(parseAll(md)),
        'Doc(1)\n  Code(lang="dart", 1L) OPEN\n    > "print(1);"',
      );
    });

    test('blockquote with single paragraph', () {
      expect(
        snapshot(parseAll('> hello\n')),
        'Doc(1)\n  Q(d=1, 1)\n    P("hello")',
      );
    });

    test('blockquote with two paragraph lines', () {
      // Both > prefixed.
      expect(
        snapshot(parseAll('> first\n> second\n')),
        'Doc(1)\n  Q(d=1, 1)\n    P("first\nsecond")',
      );
    });

    test('unordered list with two items', () {
      expect(
        snapshot(parseAll('- one\n- two\n')),
        'Doc(1)\n  List(ul, 2)\n    Item(1)\n      P("one")\n    Item(1)\n      P("two")',
      );
    });

    test('ordered list with start number 42', () {
      expect(
        snapshot(parseAll('42. forty-two\n43. forty-three\n')),
        'Doc(1)\n  List(ol, 2)\n    Item(1)\n      P("forty-two")\n    Item(1)\n      P("forty-three")',
      );
    });

    test('task list', () {
      expect(
        snapshot(parseAll('- [ ] todo\n- [x] done\n')),
        'Doc(1)\n  List(ul, 2)\n    Item[ ](1)\n      P("todo")\n    Item[x](1)\n      P("done")',
      );
    });

    test('simple GFM table', () {
      const md = '| a | b |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |\n';
      expect(
        snapshot(parseAll(md)),
        'Doc(1)\n  Table(h=2, 2R)\n    H: [a, b]\n    A: none,none\n    R: [1, 2]\n    R: [3, 4]',
      );
    });

    test('GFM table with alignments', () {
      const md = '| l | c | r |\n|:--|:--:|--:|\n| a | b | c |\n';
      expect(
        snapshot(parseAll(md)),
        'Doc(1)\n  Table(h=3, 1R)\n    H: [l, c, r]\n    A: left,center,right\n    R: [a, b, c]',
      );
    });

    test('table row without separator → paragraph', () {
      expect(snapshot(parseAll('| a | b |\n')), 'Doc(1)\n  P("a | b")');
    });
  });

  group('Parser — mixed and complex documents', () {
    test('heading + paragraph + code + HR + list', () {
      const md =
          '# Title\n\nparagraph text\n\n```dart\nprint(1);\n```\n\n---\n\n- one\n- two\n';
      final s = snapshot(parseAll(md));
      expect(s, contains('H1("Title")'));
      expect(s, contains('P("paragraph text")'));
      expect(s, contains('Code(lang="dart", 1L)'));
      expect(s, contains('HR'));
      expect(s, contains('List(ul, 2)'));
    });

    test('paragraph after list closes the list', () {
      const md = '- a\n- b\n\nparagraph\n';
      final s = snapshot(parseAll(md));
      expect(s, contains('List(ul, 2)'));
      expect(s, contains('P("paragraph")'));
      // Paragraph should be a sibling of List, not a child.
      final doc = parseAll(md);
      expect(doc.children.last, isA<ParagraphNode>());
    });

    test('switching ordered/unordered creates new list', () {
      const md = '- a\n1. b\n';
      final doc = parseAll(md);
      expect(doc.children, hasLength(2));
      expect(doc.children[0], isA<ListNode>());
      expect((doc.children[0] as ListNode).ordered, isFalse);
      expect(doc.children[1], isA<ListNode>());
      expect((doc.children[1] as ListNode).ordered, isTrue);
    });

    test('code block content is verbatim — # inside is not a heading', () {
      const md = '```\n# not a heading\n```\n';
      final doc = parseAll(md);
      expect(doc.children, hasLength(1));
      final code = doc.children.first as CodeBlockNode;
      expect(code.lines, ['# not a heading']);
    });

    test('paragraph then heading closes paragraph', () {
      const md = 'paragraph\n# heading\n';
      final doc = parseAll(md);
      expect(doc.children, hasLength(2));
      expect(doc.children[0], isA<ParagraphNode>());
      expect((doc.children[0] as ParagraphNode).isComplete, isTrue);
      expect(doc.children[1], isA<HeadingNode>());
    });

    test('table immediately followed by paragraph', () {
      const md = '| h |\n|---|\n| x |\n\nafter\n';
      final doc = parseAll(md);
      expect(doc.children, hasLength(2));
      expect(doc.children[0], isA<TableNode>());
      expect(doc.children[1], isA<ParagraphNode>());
    });
  });

  group('Parser — provisional / open state', () {
    test('open paragraph (no terminating newline) is OPEN', () {
      // Feed half a paragraph without complete() — verify it's still open.
      final tok = Tokenizer();
      final p = Parser();
      p.feed(tok.feed('hello world'));
      // No newline → not yet emitted as token → no node.
      expect(p.document.children, isEmpty);

      // Now emit the newline.
      p.feed(tok.feed('\n'));
      expect(p.document.children, hasLength(1));
      final para = p.document.children.first as ParagraphNode;
      expect(
        para.isComplete,
        isFalse,
        reason: 'paragraph is open until a block boundary',
      );
      expect(para.text, 'hello world');

      // Add a blank line — closes it.
      p.feed(tok.feed('\n'));
      expect(para.isComplete, isTrue);
    });

    test('mid-stream code block is OPEN', () {
      final tok = Tokenizer();
      final p = Parser();
      p.feed(tok.feed('```dart\nprint(1);\n'));
      expect(p.document.children, hasLength(1));
      final code = p.document.children.first as CodeBlockNode;
      expect(code.language, 'dart');
      expect(code.lines, ['print(1);']);
      expect(code.isComplete, isFalse);

      // Close the fence.
      p.feed(tok.feed('```\n'));
      expect(code.isComplete, isTrue);
    });
  });

  group('Parser — chunked vs whole equivalence', () {
    final samples = <String>[
      '# A\nparagraph\n',
      '```js\nconst x = 1;\nconst y = 2;\n```\n',
      '- one\n- two\n- three\n',
      '1. first\n2. second\n3. third\n',
      '> quoted line one\n> quoted line two\n',
      '| a | b |\n|---|---|\n| 1 | 2 |\n',
      '# Title\n\np1\n\np2\n\n---\n',
      'paragraph\nwith soft\nbreaks\n',
      '- [ ] todo\n- [x] done\n',
      '```\n# in code\n> in code\n- in code\n```\n',
    ];

    for (var idx = 0; idx < samples.length; idx++) {
      test('sample $idx — char-by-char == whole feed', () {
        final s = samples[idx];
        expect(snapshot(parseChunked(s)), snapshot(parseAll(s)));
      });

      test('sample $idx — 5-char chunks == whole feed', () {
        final s = samples[idx];
        expect(snapshot(parseChunked(s, chunkSize: 5)), snapshot(parseAll(s)));
      });

      test('sample $idx — 13-char chunks == whole feed', () {
        final s = samples[idx];
        expect(snapshot(parseChunked(s, chunkSize: 13)), snapshot(parseAll(s)));
      });
    }
  });

  group('Parser — invariants', () {
    test('node IDs are monotonic and unique', () {
      final doc = parseAll('# A\n\nP\n\n```\ncode\n```\n\n- li\n');
      final ids = <int>{};
      void collect(AstNode n) {
        expect(ids.add(n.id), isTrue, reason: 'duplicate id ${n.id}');
        switch (n) {
          case DocumentNode(:final children):
            children.forEach(collect);
          case BlockquoteNode(:final children):
            children.forEach(collect);
          case ListNode(:final items):
            items.forEach(collect);
          case ListItemNode(:final children):
            children.forEach(collect);
          default:
        }
      }

      collect(doc);
      // Should be monotonic — sorted set equals 0..N.
      final sorted = ids.toList()..sort();
      for (var i = 0; i < sorted.length; i++) {
        expect(sorted[i], i, reason: 'expected monotonic IDs starting at 0');
      }
    });

    test('closed nodes do not mutate after subsequent feeds', () {
      final tok = Tokenizer();
      final p = Parser();
      p.feed(tok.feed('# Done\n\n'));
      final h = p.document.children.first as HeadingNode;
      expect(h.text, 'Done');
      expect(h.isComplete, isTrue);

      // Feed more — heading should be untouched.
      p.feed(tok.feed('## New\n'));
      expect(h.text, 'Done');
      expect(h.level, 1);
    });

    test('complete() finalizes everything', () {
      final tok = Tokenizer();
      final p = Parser();
      p.feed(tok.feed('```\nfoo\n')); // unclosed fence
      expect(p.document.children.first.isComplete, isFalse);
      p.feed(tok.complete());
      p.complete();
      expect(
        p.document.children.first.isComplete,
        isFalse,
        reason:
            'unclosed fence stays open even after complete — caller decides',
      );
      expect(p.document.isComplete, isTrue);
    });
  });

  group('Parser — provisional trailing line', () {
    /// 模拟 widget 行为：每次 feed 后把未完成尾行作为 provisional 渲染。
    DocumentNode parseStreaming(List<String> chunks) {
      final tok = Tokenizer();
      final p = Parser();
      for (final chunk in chunks) {
        p.feed(tok.feed(chunk));
        final pending = tok.pendingLine;
        if (pending.isNotEmpty) {
          p.feedProvisional(pending);
        }
      }
      p.feed(tok.complete());
      p.complete();
      return p.document;
    }

    test('paragraph grows in place without duplication', () {
      final doc = parseStreaming(['你好', '世界', '！\n', '第二段']);
      final paragraphs = doc.children.whereType<ParagraphNode>().toList();
      // 无空行分隔 → CommonMark soft-break 语义：同一段落
      expect(paragraphs.length, 1);
      expect(paragraphs[0].text, '你好世界！\n第二段');
    });

    test('unfinished line visible before newline, replaced after', () {
      final tok = Tokenizer();
      final p = Parser();
      p.feed(tok.feed('Hello'));
      p.feedProvisional(tok.pendingLine);
      var para = p.document.children.first as ParagraphNode;
      expect(para.text, 'Hello');
      p.feed(tok.feed(' world\n'));
      p.feedProvisional(tok.pendingLine);
      para = p.document.children.first as ParagraphNode;
      expect(para.text, 'Hello world');
      p.feed(tok.complete());
      p.complete();
      expect(p.document.children.length, 1);
      expect(para.text, 'Hello world');
    });

    test('code block content streams line by line', () {
      final doc = parseStreaming(['```dart\n', 'void main(', ') {', '}\n', '```\n']);
      final code = doc.children.first as CodeBlockNode;
      expect(code.language, 'dart');
      // 'void main(' + ') {' + '}' 是无换行拼接（provisional 逐字增长）
      expect(code.lines, ['void main() {}']);
      expect(code.isComplete, isTrue);
    });

    test('unfinished closing fence is not kept as content', () {
      final doc = parseStreaming(['```\n', 'code\n', '``', '`\n']);
      final code = doc.children.first as CodeBlockNode;
      expect(code.lines, ['code']);
      expect(code.isComplete, isTrue);
    });

    test('block starter removes temporary provisional paragraph', () {
      final tok = Tokenizer();
      final p = Parser();
      p.feed(tok.feed('```pyt'));
      p.feedProvisional(tok.pendingLine);
      // provisional 阶段把 ```pyt 渲染成了临时段落
      expect(p.document.children.first, isA<ParagraphNode>());
      p.feed(tok.feed('hon\n'));
      p.feedProvisional(tok.pendingLine);
      p.feed(tok.feed('x = 1\n'));
      p.feed(tok.complete());
      p.complete();
      // 真实 fence 行到达后临时段落被移除，只剩代码块
      expect(p.document.children.length, 1);
      final code = p.document.children.first as CodeBlockNode;
      expect(code.language, 'python');
      expect(code.lines, ['x = 1']);
    });

    test('blank line finalizes provisional paragraph cleanly', () {
      final doc = parseStreaming(['first', '\n', '\n', 'second']);
      final paragraphs = doc.children.whereType<ParagraphNode>().toList();
      expect(paragraphs.length, 2);
      expect(paragraphs[0].text, 'first');
      expect(paragraphs[1].text, 'second');
    });
  });
}
