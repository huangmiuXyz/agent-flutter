import 'package:flutter/material.dart';

import 'paragraph_utils.dart';

/// A virtual-scrolling widget that renders plain [text] as a list of
/// paragraphs.
///
/// Under the hood it uses [ListView.builder], which is itself a virtual list –
/// only paragraphs near the viewport are built.  Paragraph heights are
/// determined naturally by their content, so no manual height estimation is
/// needed.
///
/// Features:
/// - Automatic paragraph splitting (blank-line delimited by default).
/// - Stick-to-bottom mode (auto-scroll on content append).
/// - Custom paragraph builder (slot-like API).
///
/// Usage in a flex layout:
/// ```dart
/// Column(
///   children: [
///     Expanded(
///       child: VirtualParagraphText(
///         text: someLongString,
///         stickToBottom: true,
///       ),
///     ),
///   ],
/// )
/// ```
class VirtualParagraphText extends StatefulWidget {
  /// The raw text to display.
  final String text;

  /// Fixed height of the viewport.  Omit (or pass null) to let a parent
  /// `Expanded` / `Flexible` govern the height.
  final double? height;

  /// Maximum height of the viewport.  When set without [height], the widget
  /// will size itself naturally but never exceed [maxHeight].
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

  // Each paragraph gets a GlobalKey so scrollToParagraph can use
  // Scrollable.ensureVisible instead of estimated offsets.
  final List<GlobalKey> _itemKeys = [];

  // ── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _paragraphs = _splitText();
    _rebuildKeys();
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
        _rebuildKeys();
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

  void _rebuildKeys() {
    _itemKeys
      ..clear()
      ..addAll(List.generate(_paragraphs.length, (_) => GlobalKey()));
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

  /// Scroll so that paragraph at [index] is visible.
  ///
  /// Uses [Scrollable.ensureVisible] so the exact position is accurate even
  /// with variable-height paragraphs.
  void scrollToParagraph(int index) {
    final safeIndex = index.clamp(0, _paragraphs.length - 1);
    final key = _itemKeys[safeIndex];
    final context = key.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
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
    Widget child;

    if (_paragraphs.isEmpty) {
      child = widget.emptyBuilder?.call() ?? const SizedBox.shrink();
    } else {
      child = ListView.builder(
        controller: _scrollController,
        itemCount: _paragraphs.length,
        itemBuilder: (context, index) {
          final paragraph = _paragraphs[index];

          final body =
              widget.paragraphBuilder?.call(paragraph, index) ??
              _defaultParagraphBuilder(paragraph, index);

          return Padding(
            key: _itemKeys[index],
            padding: EdgeInsets.only(bottom: widget.paragraphGap),
            child: body,
          );
        },
      );
    }

    // Apply height / maxHeight constraints.
    if (widget.maxHeight != null) {
      child = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight!),
        child: child,
      );
    }
    if (widget.height != null) {
      child = SizedBox(height: widget.height, child: child);
    }

    return child;
  }
}
