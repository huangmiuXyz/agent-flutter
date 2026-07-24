import 'package:flutter/material.dart';

import 'paragraph_utils.dart';
export 'paragraph_utils.dart' show ParagraphBlock, ParagraphSplitMode;

/// A virtual-scrolling widget that renders plain [text] as a list of
/// paragraphs.
///
/// Under the hood it uses [ListView.builder], which is itself a virtual list –
/// only paragraphs near the viewport are built.  Paragraph heights are
/// determined naturally by their content, so no manual height estimation is
/// needed.
///
/// **Adaptive height** (when [maxHeight] is set without [height]):
/// the widget estimates the total content height at build time.  If the
/// content fits within [maxHeight] it shrinks to the content's natural height;
/// otherwise it takes [maxHeight] and scrolls virtually.  This eliminates
/// wasted space when the text is short.
///
/// Features:
/// - Automatic paragraph splitting (blank-line delimited by default).
/// - Stick-to-bottom mode (auto-scroll on content append).
/// - Custom paragraph builder (slot-like API).
///
/// Performance note: this widget does **not** allocate per-paragraph keys,
/// so even huge texts (tens of thousands of paragraphs) expand instantly.
/// `scrollToParagraph` uses a character‑count heuristic to estimate the
/// scroll offset, which is fast but approximate.
class VirtualParagraphText extends StatefulWidget {
  /// The raw text to display.
  final String text;

  /// Fixed height of the viewport.  When set the widget always takes exactly
  /// this height and scrolls internally.
  final double? height;

  /// Maximum height of the viewport.
  ///
  /// When set without [height] the widget adapts:
  /// - content shorter than [maxHeight] → natural height (no wasted space)
  /// - content taller than [maxHeight] → exactly [maxHeight], virtual‑scrolled
  ///
  /// When unset the widget relies on a bounded parent (e.g. `Expanded`).
  final double? maxHeight;

  /// Paragraph splitting strategy.
  final ParagraphSplitMode splitMode;

  /// Whether to keep empty paragraphs.
  final bool preserveEmpty;

  /// Whether to `.trim()` each paragraph.
  final bool trimParagraphs;

  /// Font size used for the default paragraph style.
  final double fontSize;

  /// Line height used for the default paragraph style.
  final double lineHeight;

  /// Vertical padding (top + bottom) applied inside each paragraph.
  final double paragraphPaddingBlock;

  /// Gap between consecutive paragraphs.  Applied as bottom margin of each
  /// item.
  final double paragraphGap;

  /// Whether to automatically scroll to the bottom when new content arrives.
  ///
  /// Once the user scrolls away from the bottom, auto-scroll pauses until
  /// they scroll back within [bottomThreshold] of the bottom edge.
  final bool stickToBottom;

  /// Distance from the bottom (logical px) within which the viewport is
  /// considered "pinned to bottom".
  final double bottomThreshold;

  /// Builder for a custom paragraph widget.  When null, a plain [Text] widget
  /// styled with [fontSize] and [lineHeight] is used.
  ///
  /// The returned widget does **not** need to worry about spacing – the widget
  /// applies [paragraphPaddingBlock] and [paragraphGap] around the built
  /// widget.
  final Widget Function(ParagraphBlock paragraph, int index)? paragraphBuilder;

  /// Builder shown when there are no paragraphs.
  final Widget Function()? emptyBuilder;

  const VirtualParagraphText({
    super.key,
    required this.text,
    this.height,
    this.maxHeight,
    this.splitMode = ParagraphSplitMode.blankLine,
    this.preserveEmpty = false,
    this.trimParagraphs = false,
    this.fontSize = 14,
    this.lineHeight = 22,
    this.paragraphPaddingBlock = 12,
    this.paragraphGap = 8,
    this.stickToBottom = false,
    this.bottomThreshold = 24,
    this.paragraphBuilder,
    this.emptyBuilder,
  });

  @override
  State<VirtualParagraphText> createState() => _VirtualParagraphTextState();
}

class _VirtualParagraphTextState extends State<VirtualParagraphText> {
  final ScrollController _scrollController = ScrollController();
  late List<ParagraphBlock> _paragraphs;
  bool _isPinnedToBottom = false;

  /// Cumulative character count before each paragraph, used by
  /// [scrollToParagraph] for offset estimation.
  late List<int> _cumulativeChars;

  // ── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _paragraphs = _splitText();
    _computeCumulativeChars();
    _isPinnedToBottom = widget.stickToBottom;
    _scrollController.addListener(_onScroll);
    _maybeScrollToBottomAfterBuild();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VirtualParagraphText old) {
    super.didUpdateWidget(old);

    final needsResplit =
        widget.text != old.text ||
        widget.splitMode != old.splitMode ||
        widget.preserveEmpty != old.preserveEmpty ||
        widget.trimParagraphs != old.trimParagraphs;

    if (needsResplit) {
      setState(() {
        _paragraphs = _splitText();
        _computeCumulativeChars();
      });
      _maybeScrollToBottomAfterBuild();
    }

    if (widget.stickToBottom != old.stickToBottom) {
      setState(() {
        _isPinnedToBottom =
            widget.stickToBottom &&
            _scrollController.hasClients &&
            _isNearBottom();
      });
    }
  }

  // ── Text helpers ───────────────────────────────────────────────────────

  List<ParagraphBlock> _splitText() => splitTextIntoParagraphs(
    widget.text,
    mode: widget.splitMode,
    preserveEmpty: widget.preserveEmpty,
    trimParagraphs: widget.trimParagraphs,
  );

  void _computeCumulativeChars() {
    _cumulativeChars = List.filled(_paragraphs.length + 1, 0);
    for (int i = 0; i < _paragraphs.length; i++) {
      _cumulativeChars[i + 1] =
          _cumulativeChars[i] + _paragraphs[i].text.length;
    }
  }

  /// Fast O(n) estimate of total rendered height in pixels, used to decide
  /// shrink‑wrap vs. virtual scrolling.
  double _estimateTotalHeight(double containerWidth) {
    double total = 0;
    for (final p in _paragraphs) {
      total += estimateParagraphHeight(
        p.text,
        containerWidth: containerWidth,
        fontSize: widget.fontSize,
        lineHeight: widget.lineHeight,
        paddingBlock: widget.paragraphPaddingBlock,
        gap: widget.paragraphGap,
        minHeight:
            widget.paragraphGap +
            widget.paragraphPaddingBlock +
            widget.lineHeight,
      );
    }
    return total;
  }

  // ── Scroll helpers ─────────────────────────────────────────────────────

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return false;
    final pos = _scrollController.position;
    return pos.maxScrollExtent - pos.pixels <= widget.bottomThreshold;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (!widget.stickToBottom) return;

    final nearBottom = _isNearBottom();
    if (nearBottom != _isPinnedToBottom) {
      setState(() {
        _isPinnedToBottom = nearBottom;
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients || _paragraphs.isEmpty) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 30),
      curve: Curves.easeOut,
    );
  }

  void _maybeScrollToBottomAfterBuild() {
    if (!widget.stickToBottom || !_isPinnedToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });
  }

  // ── Public API ─────────────────────────────────────────────────────────

  /// The current list of paragraphs (derived from [text]).
  List<ParagraphBlock> get paragraphs => _paragraphs;

  /// Whether the viewport is currently pinned to the bottom.
  bool get isPinnedToBottom => _isPinnedToBottom;

  /// Scroll so that paragraph at [index] is roughly visible.
  ///
  /// Uses a character‑count heuristic to estimate the scroll offset – this is
  /// fast and does not require per‑paragraph keys, but is only an
  /// approximation when paragraphs have varying line heights or wrapping.
  void scrollToParagraph(int index) {
    if (!_scrollController.hasClients) return;
    final safeIndex = index.clamp(0, _paragraphs.length - 1);
    final total = _cumulativeChars.last;
    if (total == 0) return;

    final proportion = _cumulativeChars[safeIndex] / total;
    final offset = (proportion * _scrollController.position.maxScrollExtent)
        .clamp(0.0, _scrollController.position.maxScrollExtent);

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  /// Scroll to the very first paragraph.
  void scrollToTop() => scrollToParagraph(0);

  /// Scroll to the last paragraph.
  void scrollToBottom() => _scrollToBottom();

  // ── Default paragraph widget ───────────────────────────────────────────

  Widget _defaultParagraphBuilder(ParagraphBlock paragraph, int index) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.paragraphPaddingBlock / 2),
      child: Text(
        paragraph.text,
        style: TextStyle(
          fontSize: widget.fontSize,
          height: widget.lineHeight / widget.fontSize,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_paragraphs.isEmpty) {
      return widget.emptyBuilder?.call() ?? const SizedBox.shrink();
    }

    // Determine the effective viewport constraint.
    //   - [height]  → exact (always virtual)
    //   - [maxHeight] → cap (estimate content; shrink-wrap if it fits;
    //                    virtual-scroll with maxHeight otherwise)
    //   - neither  → rely on parent to give bounded constraints
    //
    // We build the content via [_buildContent], then apply height/maxHeight.

    Widget content;

    if (widget.height != null) {
      // Exact height — normal virtual list.
      content = _buildListView();
    } else if (widget.maxHeight != null) {
      // MaxHeight with auto-sizing — provide our own cap so LayoutBuilder
      // sees bounded constraints even when the parent Column doesn't.
      content = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight!),
        child: _adaptiveContent(),
      );
    } else {
      // No constraint — defer to LayoutBuilder for whatever the parent gives.
      content = _adaptiveContent();
    }

    return content;
  }

  /// Uses [LayoutBuilder] to decide between virtual‑scroll and shrink‑wrap.
  ///
  /// When the parent provides a bounded viewport, we estimate the total
  /// content height.  If the estimate exceeds the viewport, we use a
  /// full virtual [ListView.builder]; otherwise we shrink‑wrap so the
  /// widget sizes to its natural content height.
  Widget _adaptiveContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        if (h.isFinite && h > 0) {
          final estimated = _estimateTotalHeight(w);
          if (estimated > h) {
            return _buildListView();
          }
        }

        return _buildShrinkWrapListView();
      },
    );
  }

  /// Normal virtual‑scrolling [ListView.builder].
  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _paragraphs.length,
      itemBuilder: (context, index) {
        final paragraph = _paragraphs[index];
        final body =
            widget.paragraphBuilder?.call(paragraph, index) ??
            _defaultParagraphBuilder(paragraph, index);
        return Padding(
          padding: EdgeInsets.only(bottom: widget.paragraphGap),
          child: body,
        );
      },
    );
  }

  /// Shrink‑wrapping [ListView.builder] – sizes to content, no built‑in
  /// scrolling.  All items are built once (acceptable because this path is
  /// taken only for content that is short enough to fit without scrolling).
  Widget _buildShrinkWrapListView() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _paragraphs.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final paragraph = _paragraphs[index];
        final body =
            widget.paragraphBuilder?.call(paragraph, index) ??
            _defaultParagraphBuilder(paragraph, index);
        return Padding(
          padding: EdgeInsets.only(bottom: widget.paragraphGap),
          child: body,
        );
      },
    );
  }
}
