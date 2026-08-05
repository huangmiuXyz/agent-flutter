// Incremental block-level Markdown tokenizer.
//
// Design:
//   * Append-only buffer (the user calls [feed] with each chunk).
//   * Line-based: tokens are emitted once a newline is seen for the line.
//   * Fence state persists across [feed] calls so partial fences are handled.
//   * [complete] flushes any unterminated trailing line.
//
// Inline tokens (bold, italic, code spans, links) are NOT produced here —
// see [InlineTokenizer]. Block tokenization is what needs to be incremental;
// inline tokenization can be re-run on the (small) accumulated paragraph text.

import 'token.dart';

class Tokenizer {
  Tokenizer();

  /// Buffer of characters that arrived but haven't yet been terminated by a
  /// newline. Cleared as soon as a `\n` is seen.
  String _pending = '';

  // Fence state — carried across feed() calls.
  bool _insideFence = false;
  String _fenceChar = '';
  int _fenceLength = 0;
  int _fenceIndent = 0;

  /// Append [chunk] to the input stream and return any tokens that became
  /// fully determined as a result.
  List<Token> feed(String chunk) {
    final tokens = <Token>[];
    final combined = _pending + chunk;

    var lineStart = 0;
    for (var i = 0; i < combined.length; i++) {
      if (combined.codeUnitAt(i) == 0x0A /* \n */ ) {
        var line = combined.substring(lineStart, i);
        if (line.endsWith('\r')) {
          line = line.substring(0, line.length - 1);
        }
        _classifyLine(line, tokens);
        lineStart = i + 1;
      }
    }

    _pending = combined.substring(lineStart);
    return tokens;
  }

  /// Flush any unterminated trailing line. Call once the input stream is done.
  ///
  /// Note: an unclosed fence stays "open" — its trailing partial line, if any,
  /// is emitted as a [CodeLineToken]. The caller (parser) is responsible for
  /// finalizing AST state when a stream completes without a closing fence.
  List<Token> complete() {
    final tokens = <Token>[];
    if (_pending.isNotEmpty) {
      _classifyLine(_pending, tokens);
      _pending = '';
    }
    return tokens;
  }

  /// Returns the current trailing partial line (chars that have arrived but
  /// haven't been terminated by `\n`). Useful for provisional rendering —
  /// the parser can preview the in-progress line without finalizing it.
  String get pendingLine => _pending;

  /// Whether the tokenizer is currently inside an open fenced code block.
  bool get insideFence => _insideFence;

  // ──────────────────────────────────────────────────────────────────────

  void _classifyLine(String line, List<Token> out) {
    // Lines inside a fence are either the matching close fence or a code line.
    if (_insideFence) {
      if (_isClosingFence(line)) {
        out.add(const FenceCloseToken());
        _insideFence = false;
        _fenceChar = '';
        _fenceLength = 0;
        _fenceIndent = 0;
        return;
      }
      // Strip up to _fenceIndent leading spaces (CommonMark §4.5).
      var content = line;
      var stripped = 0;
      while (stripped < _fenceIndent &&
          content.isNotEmpty &&
          content.codeUnitAt(0) == 0x20) {
        content = content.substring(1);
        stripped++;
      }
      out.add(CodeLineToken(content));
      return;
    }

    // Blank line.
    if (line.trim().isEmpty) {
      out.add(const BlankLineToken());
      return;
    }

    // Leading indent (used for list nesting).
    final indent = _leadingSpaces(line);
    final trimmed = line.substring(indent);

    // Fence open: ``` or ~~~ (>=3 of the same char). Optional info string.
    final fenceMatch = _fenceOpenRe.firstMatch(trimmed);
    if (fenceMatch != null) {
      final fence = fenceMatch.group(1)!;
      final info = fenceMatch.group(2)?.trim();
      _insideFence = true;
      _fenceChar = fence[0];
      _fenceLength = fence.length;
      _fenceIndent = indent;
      out.add(
        FenceOpenToken(
          fenceChar: _fenceChar,
          fenceLength: _fenceLength,
          language: (info == null || info.isEmpty) ? null : info,
        ),
      );
      return;
    }

    // ATX heading.
    final headingMatch = _atxHeadingRe.firstMatch(trimmed);
    if (headingMatch != null) {
      final hashes = headingMatch.group(1)!;
      var text = headingMatch.group(2) ?? '';
      // Trim optional trailing `###` close sequence and surrounding spaces.
      text = text.replaceFirst(RegExp(r'\s+#+\s*$'), '').trimRight();
      out.add(HeadingToken(hashes.length, text));
      return;
    }

    // Horizontal rule.
    if (_isHorizontalRule(trimmed)) {
      out.add(const HorizontalRuleToken());
      return;
    }

    // Blockquote (possibly nested: `>> foo`).
    if (trimmed.startsWith('>')) {
      var depth = 0;
      var rest = trimmed;
      while (rest.startsWith('>')) {
        depth++;
        rest = rest.substring(1);
        if (rest.startsWith(' ')) {
          rest = rest.substring(1);
        }
      }
      out.add(BlockquoteMarkerToken(depth));
      if (rest.trim().isEmpty) {
        return;
      }
      _classifyLine(rest, out);
      return;
    }

    // List markers.
    final ulMatch = _unorderedListRe.firstMatch(line);
    if (ulMatch != null) {
      _emitListMarker(line, ulMatch, ordered: false, indent: indent, out: out);
      return;
    }
    final olMatch = _orderedListRe.firstMatch(line);
    if (olMatch != null) {
      _emitListMarker(line, olMatch, ordered: true, indent: indent, out: out);
      return;
    }

    // Table separator (must be checked before table row).
    if (_isTableSeparator(trimmed)) {
      out.add(TableSeparatorToken(_parseAlignments(trimmed)));
      return;
    }

    // Table row (at least one `|`, not part of a paragraph wrap).
    if (_looksLikeTableRow(line)) {
      out.add(TableRowToken(_splitTableCells(line)));
      return;
    }

    // Fallback: paragraph text line.
    out.add(TextLineToken(line));
  }

  void _emitListMarker(
    String line,
    Match m, {
    required bool ordered,
    required int indent,
    required List<Token> out,
  }) {
    // Capture groups in unordered: 1=indent, 2=marker (-/*/+), 3=rest.
    // In ordered: 1=indent, 2=number, 3=delim, 4=rest.
    final restGroupIndex = ordered ? 4 : 3;
    final rest = m.group(restGroupIndex) ?? '';
    final number = ordered ? int.tryParse(m.group(2)!) : null;

    var isTask = false;
    var isChecked = false;
    var content = rest;
    final taskMatch = _taskBoxRe.firstMatch(rest);
    if (taskMatch != null) {
      isTask = true;
      isChecked = taskMatch.group(1)!.toLowerCase() == 'x';
      content = rest.substring(taskMatch.end);
    }

    out.add(
      ListMarkerToken(
        indent: indent,
        ordered: ordered,
        number: number,
        isTask: isTask,
        isChecked: isChecked,
      ),
    );

    // Treat the marker's content as the start of a paragraph text line.
    if (content.isNotEmpty) {
      out.add(TextLineToken(content));
    }
  }

  bool _isClosingFence(String line) {
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty) return false;
    if (!trimmed.startsWith(_fenceChar)) return false;
    var i = 0;
    while (i < trimmed.length && trimmed[i] == _fenceChar) {
      i++;
    }
    if (i < _fenceLength) return false;
    // After the fence chars, only whitespace is allowed.
    for (var j = i; j < trimmed.length; j++) {
      final ch = trimmed.codeUnitAt(j);
      if (ch != 0x20 && ch != 0x09) return false;
    }
    return true;
  }

  bool _isHorizontalRule(String line) {
    final s = line.replaceAll(' ', '').replaceAll('\t', '');
    if (s.length < 3) return false;
    final ch = s[0];
    if (ch != '-' && ch != '*' && ch != '_') return false;
    for (var i = 1; i < s.length; i++) {
      if (s[i] != ch) return false;
    }
    return true;
  }

  bool _isTableSeparator(String line) {
    var s = line.trim();
    if (!s.contains('|')) return false;
    if (s.startsWith('|')) s = s.substring(1);
    if (s.endsWith('|')) s = s.substring(0, s.length - 1);
    if (s.isEmpty) return false;
    final cells = s.split('|');
    for (final cell in cells) {
      final c = cell.trim();
      if (!_alignCellRe.hasMatch(c)) return false;
    }
    return cells.isNotEmpty;
  }

  List<TableAlignment> _parseAlignments(String line) {
    var s = line.trim();
    if (s.startsWith('|')) s = s.substring(1);
    if (s.endsWith('|')) s = s.substring(0, s.length - 1);
    return s
        .split('|')
        .map((c) {
          final t = c.trim();
          final left = t.startsWith(':');
          final right = t.endsWith(':');
          if (left && right) return TableAlignment.center;
          if (right) return TableAlignment.right;
          if (left) return TableAlignment.left;
          return TableAlignment.none;
        })
        .toList(growable: false);
  }

  bool _looksLikeTableRow(String line) {
    if (!line.contains('|')) return false;
    // A line that's all whitespace except for one pipe at the end isn't a row.
    final stripped = line.trim();
    if (stripped == '|') return false;
    return true;
  }

  List<String> _splitTableCells(String line) {
    var s = line.trim();
    if (s.startsWith('|')) s = s.substring(1);
    if (s.endsWith('|')) s = s.substring(0, s.length - 1);
    final cells = <String>[];
    final sb = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == r'\' && i + 1 < s.length && s[i + 1] == '|') {
        sb.write('|');
        i++;
        continue;
      }
      if (c == '|') {
        cells.add(sb.toString().trim());
        sb.clear();
        continue;
      }
      sb.write(c);
    }
    cells.add(sb.toString().trim());
    return cells;
  }

  int _leadingSpaces(String s) {
    var i = 0;
    while (i < s.length && s.codeUnitAt(i) == 0x20) {
      i++;
    }
    return i;
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Regexes (compiled once, reused)
// ──────────────────────────────────────────────────────────────────────────

final RegExp _atxHeadingRe = RegExp(r'^(#{1,6})(?:[ \t]+(.*))?$');

final RegExp _fenceOpenRe = RegExp(r'^(`{3,}|~{3,})[ \t]*([^`]*)$');

final RegExp _unorderedListRe = RegExp(r'^(\s*)([-*+])[ \t]+(.*)$');

final RegExp _orderedListRe = RegExp(r'^(\s*)(\d{1,9})([.)])[ \t]+(.*)$');

final RegExp _taskBoxRe = RegExp(r'^\[( |x|X)\][ \t]+');

final RegExp _alignCellRe = RegExp(r'^:?-{1,}:?$');
