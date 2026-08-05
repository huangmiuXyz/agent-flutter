// Token hierarchy for the streamdown tokenizer.
//
// Two flavors:
//   * Block tokens — produced by [Tokenizer] from raw line input.
//   * Inline tokens — produced by [InlineTokenizer] from accumulated paragraph
//     / heading / cell text.
//
// Delimiters (strong / emphasis / strike) are emitted as flat tokens; the
// parser performs CommonMark-style pairing in Phase 2.

sealed class Token {
  const Token();
}

// ──────────────────────────────────────────────────────────────────────────
// Block-level tokens (one per line, except BlockquoteMarker which prefixes)
// ──────────────────────────────────────────────────────────────────────────

/// `# Heading` through `###### Heading` (ATX).
final class HeadingToken extends Token {
  const HeadingToken(this.level, this.text);

  final int level; // 1..6
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeadingToken && other.level == level && other.text == text;

  @override
  int get hashCode => Object.hash(level, text);

  @override
  String toString() => 'HeadingToken(level: $level, text: ${_q(text)})';
}

/// Three or more `-`, `*`, or `_` alone on a line.
final class HorizontalRuleToken extends Token {
  const HorizontalRuleToken();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HorizontalRuleToken;

  @override
  int get hashCode => 0x484F525A;

  @override
  String toString() => 'HorizontalRuleToken()';
}

/// `> quote` — depth = number of consecutive `>` markers.
final class BlockquoteMarkerToken extends Token {
  const BlockquoteMarkerToken(this.depth);

  final int depth;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockquoteMarkerToken && other.depth == depth;

  @override
  int get hashCode => Object.hash('blockquote', depth);

  @override
  String toString() => 'BlockquoteMarkerToken(depth: $depth)';
}

/// `- foo`, `* foo`, `+ foo`, `1. foo`, etc.
final class ListMarkerToken extends Token {
  const ListMarkerToken({
    required this.indent,
    required this.ordered,
    this.number,
    this.isTask = false,
    this.isChecked = false,
  });

  final int indent;
  final bool ordered;
  final int? number;
  final bool isTask;
  final bool isChecked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListMarkerToken &&
          other.indent == indent &&
          other.ordered == ordered &&
          other.number == number &&
          other.isTask == isTask &&
          other.isChecked == isChecked;

  @override
  int get hashCode => Object.hash(indent, ordered, number, isTask, isChecked);

  @override
  String toString() =>
      'ListMarkerToken(indent: $indent, ordered: $ordered, number: $number, '
      'isTask: $isTask, isChecked: $isChecked)';
}

/// ` ```dart ` or ` ~~~js ` — opens a fenced code block.
final class FenceOpenToken extends Token {
  const FenceOpenToken({
    required this.fenceChar,
    required this.fenceLength,
    this.language,
  });

  final String fenceChar; // '`' or '~'
  final int fenceLength;
  final String? language;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FenceOpenToken &&
          other.fenceChar == fenceChar &&
          other.fenceLength == fenceLength &&
          other.language == language;

  @override
  int get hashCode => Object.hash(fenceChar, fenceLength, language);

  @override
  String toString() =>
      'FenceOpenToken(char: $fenceChar, len: $fenceLength, lang: ${_q(language)})';
}

/// Matching closing ` ``` ` for the open fence.
final class FenceCloseToken extends Token {
  const FenceCloseToken();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FenceCloseToken;

  @override
  int get hashCode => 0x46454E43;

  @override
  String toString() => 'FenceCloseToken()';
}

/// A literal line inside a fence.
final class CodeLineToken extends Token {
  const CodeLineToken(this.content);

  final String content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodeLineToken && other.content == content;

  @override
  int get hashCode => Object.hash('code', content);

  @override
  String toString() => 'CodeLineToken(${_q(content)})';
}

/// A GFM table row (pipe-separated raw cell contents — not yet inline-tokenized).
final class TableRowToken extends Token {
  const TableRowToken(this.cells);

  final List<String> cells;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TableRowToken) return false;
    if (other.cells.length != cells.length) return false;
    for (var i = 0; i < cells.length; i++) {
      if (other.cells[i] != cells[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(cells);

  @override
  String toString() => 'TableRowToken($cells)';
}

/// `|--|:--|--:|:--:|` — GFM table separator row with alignment markers.
final class TableSeparatorToken extends Token {
  const TableSeparatorToken(this.alignments);

  final List<TableAlignment> alignments;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TableSeparatorToken) return false;
    if (other.alignments.length != alignments.length) return false;
    for (var i = 0; i < alignments.length; i++) {
      if (other.alignments[i] != alignments[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(alignments);

  @override
  String toString() => 'TableSeparatorToken($alignments)';
}

enum TableAlignment { none, left, center, right }

/// One line of paragraph text. Inline tokens are split lazily by the parser.
final class TextLineToken extends Token {
  const TextLineToken(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TextLineToken && other.text == text;

  @override
  int get hashCode => Object.hash('text', text);

  @override
  String toString() => 'TextLineToken(${_q(text)})';
}

/// A blank line — paragraph break / list-tightness signal.
final class BlankLineToken extends Token {
  const BlankLineToken();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BlankLineToken;

  @override
  int get hashCode => 0x424C4B;

  @override
  String toString() => 'BlankLineToken()';
}

// ──────────────────────────────────────────────────────────────────────────
// Inline tokens (produced by InlineTokenizer)
// ──────────────────────────────────────────────────────────────────────────

/// Plain text run.
final class InlineTextToken extends Token {
  const InlineTextToken(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is InlineTextToken && other.text == text;

  @override
  int get hashCode => Object.hash('inline', text);

  @override
  String toString() => 'InlineTextToken(${_q(text)})';
}

/// `**` strong delimiter (pairing resolved at parse time).
final class StrongDelimToken extends Token {
  const StrongDelimToken();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StrongDelimToken;

  @override
  int get hashCode => 0x53545247;

  @override
  String toString() => 'StrongDelimToken()';
}

/// `*` or `_` emphasis delimiter (pairing resolved at parse time).
final class EmphasisDelimToken extends Token {
  const EmphasisDelimToken(this.char);

  final String char; // '*' or '_'

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmphasisDelimToken && other.char == char;

  @override
  int get hashCode => Object.hash('em', char);

  @override
  String toString() => 'EmphasisDelimToken($char)';
}

/// `~~` strikethrough delimiter.
final class StrikeDelimToken extends Token {
  const StrikeDelimToken();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StrikeDelimToken;

  @override
  int get hashCode => 0x5354524B;

  @override
  String toString() => 'StrikeDelimToken()';
}

/// `` `code` `` — content already extracted; no further inlines inside.
final class CodeSpanToken extends Token {
  const CodeSpanToken(this.content);

  final String content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodeSpanToken && other.content == content;

  @override
  int get hashCode => Object.hash('codespan', content);

  @override
  String toString() => 'CodeSpanToken(${_q(content)})';
}

/// `[text](url)` or `![alt](url)`.
final class LinkToken extends Token {
  const LinkToken({
    required this.text,
    required this.url,
    this.title,
    this.isImage = false,
  });

  final String text;
  final String url;
  final String? title;
  final bool isImage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkToken &&
          other.text == text &&
          other.url == url &&
          other.title == title &&
          other.isImage == isImage;

  @override
  int get hashCode => Object.hash('link', text, url, title, isImage);

  @override
  String toString() =>
      'LinkToken(text: ${_q(text)}, url: ${_q(url)}, '
      'title: ${_q(title)}, isImage: $isImage)';
}

/// `<https://...>` autolink.
final class AutolinkToken extends Token {
  const AutolinkToken(this.url);

  final String url;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AutolinkToken && other.url == url;

  @override
  int get hashCode => Object.hash('autolink', url);

  @override
  String toString() => 'AutolinkToken(${_q(url)})';
}

/// `$...$` (inline) or `$$...$$` (block) TeX math, when LaTeX rendering is
/// enabled on the parent widget. Otherwise the dollar signs are plain text.
final class MathToken extends Token {
  const MathToken(this.tex, {this.isBlock = false});

  final String tex;
  final bool isBlock;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MathToken && other.tex == tex && other.isBlock == isBlock;

  @override
  int get hashCode => Object.hash('math', tex, isBlock);

  @override
  String toString() => 'MathToken(${_q(tex)}, isBlock: $isBlock)';
}

/// Trailing two-or-more spaces before newline, or trailing `\` — hard line break.
final class HardBreakToken extends Token {
  const HardBreakToken();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HardBreakToken;

  @override
  int get hashCode => 0x48425245;

  @override
  String toString() => 'HardBreakToken()';
}

// ──────────────────────────────────────────────────────────────────────────

String _q(String? s) => s == null ? 'null' : '"${s.replaceAll('"', r'\"')}"';
