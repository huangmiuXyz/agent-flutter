import 'dart:math';

/// A single paragraph block produced by [splitTextIntoParagraphs].
class ParagraphBlock {
  final String id;
  final String text;

  const ParagraphBlock({required this.id, required this.text});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParagraphBlock && id == other.id && text == other.text;

  @override
  int get hashCode => Object.hash(id, text);
}

/// How to detect paragraph boundaries when splitting raw text.
enum ParagraphSplitMode {
  /// Split on one or more blank lines (i.e. two newlines with optional
  /// whitespace in between).
  blankLine,

  /// Split on every newline (`\n`).  Each line becomes its own paragraph.
  /// Best for code, JSON, file contents and other line-oriented output where
  /// blank lines are rare and lines can be very long.
  newline,
}

/// Splits [text] into a list of [ParagraphBlock]s.
///
/// [mode] controls the splitting strategy.
/// When [preserveEmpty] is false, empty paragraphs are discarded.
/// When [trimParagraphs] is true, each paragraph is trimmed before keeping.
List<ParagraphBlock> splitTextIntoParagraphs(
  String text, {
  ParagraphSplitMode mode = ParagraphSplitMode.blankLine,
  bool preserveEmpty = false,
  bool trimParagraphs = false,
}) {
  if (text.isEmpty) return const [];

  final parts = switch (mode) {
    ParagraphSplitMode.blankLine => text.split(RegExp(r'\n\s*\n')),
    ParagraphSplitMode.newline => text.split('\n'),
  };

  final result = <ParagraphBlock>[];
  int idCounter = 0;
  for (final part in parts) {
    final processed = trimParagraphs ? part.trim() : part;
    if (!preserveEmpty && processed.isEmpty) continue;
    result.add(ParagraphBlock(id: 'p_${idCounter++}', text: processed));
  }
  return result;
}

/// 剥离工具输出开头的 `exit code: N` 行。
///
/// `shell_command` 的返回文本以退出码开头（供模型判断成败，对齐 codex），
/// UI 展示命令输出时无需显示此前缀；无前缀时原样返回。
String stripExitCodeLine(String text) {
  final m = RegExp(r'^exit code: -?\d+\r?\n').firstMatch(text);
  if (m == null) return text;
  return text.substring(m.end);
}

/// Estimates the rendered height (in logical pixels) of a single paragraph
/// of [text] when rendered with the given typographic settings and container
/// constraints.
///
/// This is a best-effort estimate based on average character widths.  It does
/// *not* actually lay out the text, so it is fast enough to call for every
/// paragraph on every frame.
double estimateParagraphHeight(
  String text, {
  double containerWidth = 600,
  double fontSize = 14,
  double lineHeight = 22,
  double paddingBlock = 12,
  double gap = 8,
  double minHeight = 34,
}) {
  if (text.isEmpty) return minHeight;

  // Monospace (JetBrainsMono): ~0.6 × fontSize per char.
  // For proportional fonts, ~0.5 would be more appropriate.
  const avgCharWidthRatio = 0.6;
  final avgCharWidth = fontSize * avgCharWidthRatio;
  final charsPerLine = max(1, (containerWidth / avgCharWidth).floor());

  // Sum lines accounting for explicit newlines and word-wrap.
  final lines = text.split('\n');
  int totalLines = 0;
  for (final line in lines) {
    if (line.isEmpty) {
      totalLines += 1;
    } else {
      totalLines += max(1, (line.length / charsPerLine).ceil());
    }
  }

  final height = totalLines * lineHeight + paddingBlock + gap;
  return max(height, minHeight);
}
