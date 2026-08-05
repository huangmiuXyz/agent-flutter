// AST node hierarchy.
//
// Each node carries a stable monotonic [id] so the renderer can use it as
// a Flutter widget key — closed nodes never change ID, so Flutter's element
// diff never tears them down on append.
//
// Invariants:
//   * Only the trailing open node in the tree may mutate.
//   * Once a node is marked [isComplete], it is conceptually frozen.
//     (Mutating a closed node is a parser bug — not enforced at runtime
//     for performance, but every snapshot test verifies it indirectly.)

import 'token.dart' show TableAlignment;

sealed class AstNode {
  AstNode(this.id);

  /// Monotonic, assigned at construction time. Used as the Flutter widget key.
  final int id;

  /// True once the parser has determined the node won't grow further.
  /// (`false` while it's the trailing node and might receive more content.)
  bool isComplete = false;

  @override
  String toString() => '$runtimeType#$id${isComplete ? "" : "(open)"}';
}

/// The root of an in-progress document. Owns the top-level children list.
final class DocumentNode extends AstNode {
  DocumentNode(super.id);

  final List<AstNode> children = <AstNode>[];

  @override
  String toString() =>
      'Document#$id(${children.length} child${children.length == 1 ? "" : "ren"})';
}

/// `# Heading` — level 1..6. ATX-style; setext deferred to v0.2.
final class HeadingNode extends AstNode {
  HeadingNode(super.id, {required this.level, required this.text});

  final int level;
  String text;

  @override
  String toString() => 'Heading#$id(l$level, ${_q(text)})';
}

/// A paragraph block. Multiple text lines are joined with a space, matching
/// CommonMark's soft-break semantics. (Hard breaks via trailing spaces are
/// resolved by the inline tokenizer at render time.)
final class ParagraphNode extends AstNode {
  ParagraphNode(super.id, {String text = ''}) : _text = text;

  String _text;
  String get text => _text;

  /// Append a single line. The line is joined with the existing buffer using
  /// a `\n` separator; the inline tokenizer collapses soft breaks at render.
  void appendLine(String line) {
    if (_text.isEmpty) {
      _text = line;
    } else {
      _text = '$_text\n$line';
    }
  }

  /// Replace the last line (used by provisional rendering: an unfinished
  /// trailing line is rendered immediately and replaced as it grows).
  void replaceLastLine(String line) {
    final idx = _text.lastIndexOf('\n');
    _text = idx < 0 ? line : '${_text.substring(0, idx + 1)}$line';
  }

  @override
  String toString() => 'Paragraph#$id(${_q(_text)})';
}

/// A fenced code block. Lines are stored verbatim — no inline tokenization.
final class CodeBlockNode extends AstNode {
  CodeBlockNode(super.id, {required this.language});

  final String? language;
  final List<String> lines = <String>[];

  String get content => lines.join('\n');

  @override
  String toString() =>
      'CodeBlock#$id(lang: ${_q(language)}, ${lines.length} line${lines.length == 1 ? "" : "s"})';
}

/// A blockquote. Children are themselves AstNodes (paragraphs, nested quotes,
/// lists, etc.).
final class BlockquoteNode extends AstNode {
  BlockquoteNode(super.id, {required this.depth});

  final int depth;
  final List<AstNode> children = <AstNode>[];

  @override
  String toString() =>
      'Blockquote#$id(depth: $depth, ${children.length} child${children.length == 1 ? "" : "ren"})';
}

/// An ordered or unordered list. Items are [ListItemNode]s.
final class ListNode extends AstNode {
  ListNode(super.id, {required this.ordered, this.startNumber});

  final bool ordered;
  final int? startNumber;
  final List<ListItemNode> items = <ListItemNode>[];

  @override
  String toString() =>
      'List#$id(${ordered ? "ol" : "ul"}, ${items.length} item${items.length == 1 ? "" : "s"})';
}

/// A single list item. May contain a paragraph, a nested list, or both.
final class ListItemNode extends AstNode {
  ListItemNode(
    super.id, {
    required this.indent,
    this.isTask = false,
    this.isChecked = false,
  });

  final int indent;
  final bool isTask;
  bool isChecked;
  final List<AstNode> children = <AstNode>[];

  @override
  String toString() {
    final task = isTask ? '[${isChecked ? "x" : " "}] ' : '';
    return 'ListItem#$id(indent: $indent, $task${children.length} child)';
  }
}

/// A GFM table. Header row + alignments + body rows.
final class TableNode extends AstNode {
  TableNode(super.id, {required this.headers, required this.alignments});

  final List<String> headers;
  final List<TableAlignment> alignments;
  final List<List<String>> rows = <List<String>>[];

  @override
  String toString() =>
      'Table#$id(${headers.length} cols, ${rows.length} row${rows.length == 1 ? "" : "s"})';
}

/// `---` / `***` / `___` thematic break.
final class HorizontalRuleNode extends AstNode {
  HorizontalRuleNode(super.id) {
    isComplete = true;
  }

  @override
  String toString() => 'HorizontalRule#$id';
}

String _q(String? s) => s == null ? 'null' : '"${s.replaceAll('"', r'\"')}"';
