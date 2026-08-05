// AST → Flutter widget tree.
//
// Each AstNode becomes one widget keyed by `ValueKey(node.id)` so Flutter's
// element diff never rebuilds closed nodes when new nodes are appended.
//
// Code-block syntax highlighting lands in Phase 4.
// Table layout polish lands in Phase 5.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../parser/ast.dart';
import 'code_block.dart';
import 'inline_spans.dart';
import 'syntax_theme.dart';
import 'table.dart' as table_widget;

/// Walks a [DocumentNode] and emits a [Column] of block widgets. Stateful
/// so it can own the [GestureRecognizer]s created for link taps (and dispose
/// them when the widget is removed).
class AstRenderer extends StatefulWidget {
  const AstRenderer({
    super.key,
    required this.document,
    required this.syntaxTheme,
    this.textStyle,
    this.onLinkTap,
    this.codeBlockBuilder,
    this.latex = false,
  });

  final DocumentNode document;
  final TextStyle? textStyle;
  final void Function(Uri uri)? onLinkTap;
  final SyntaxTheme syntaxTheme;
  final CodeBlockBuilder? codeBlockBuilder;
  final bool latex;

  @override
  State<AstRenderer> createState() => _AstRendererState();
}

class _AstRendererState extends State<AstRenderer> {
  final List<GestureRecognizer> _recognizers = <GestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Recognizers from the previous build are now stale — dispose & reset.
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: <Widget>[
        for (final node in widget.document.children)
          _renderBlock(context, node),
      ],
    );
  }

  Widget _renderBlock(BuildContext context, AstNode node) {
    return switch (node) {
      HeadingNode() => _Heading(
        key: ValueKey<int>(node.id),
        node: node,
        baseStyle: widget.textStyle,
        recognizers: _recognizers,
        onLinkTap: widget.onLinkTap,
        latex: widget.latex,
      ),
      ParagraphNode() => _Paragraph(
        key: ValueKey<int>(node.id),
        node: node,
        baseStyle: widget.textStyle,
        recognizers: _recognizers,
        onLinkTap: widget.onLinkTap,
        latex: widget.latex,
      ),
      HorizontalRuleNode() => Padding(
        key: ValueKey<int>(node.id),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Divider(
          color: Theme.of(context).colorScheme.outlineVariant,
          height: 1,
        ),
      ),
      BlockquoteNode() => _Blockquote(
        key: ValueKey<int>(node.id),
        node: node,
        baseStyle: widget.textStyle,
        recognizers: _recognizers,
        onLinkTap: widget.onLinkTap,
        latex: widget.latex,
      ),
      ListNode() => _List(
        key: ValueKey<int>(node.id),
        node: node,
        baseStyle: widget.textStyle,
        recognizers: _recognizers,
        onLinkTap: widget.onLinkTap,
        latex: widget.latex,
      ),
      CodeBlockNode() => CodeBlockWidget(
        key: ValueKey<int>(node.id),
        node: node,
        syntaxTheme: widget.syntaxTheme,
        builder: widget.codeBlockBuilder,
      ),
      TableNode() => table_widget.TableWidget(
        key: ValueKey<int>(node.id),
        node: node,
        baseStyle: widget.textStyle,
        recognizers: _recognizers,
        onLinkTap: widget.onLinkTap,
        latex: widget.latex,
      ),
      DocumentNode() || ListItemNode() =>
        // These should never appear at top level.
        const SizedBox.shrink(),
    };
  }
}

// ──────────────────────────────────────────────────────────────────────
// Block-level widgets
// ──────────────────────────────────────────────────────────────────────

class _Heading extends StatelessWidget {
  const _Heading({
    super.key,
    required this.node,
    required this.recognizers,
    this.baseStyle,
    this.onLinkTap,
    this.latex = false,
  });

  final HeadingNode node;
  final TextStyle? baseStyle;
  final List<GestureRecognizer> recognizers;
  final void Function(Uri uri)? onLinkTap;
  final bool latex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headingStyle = switch (node.level) {
      1 => theme.textTheme.headlineLarge,
      2 => theme.textTheme.headlineMedium,
      3 => theme.textTheme.headlineSmall,
      4 => theme.textTheme.titleLarge,
      5 => theme.textTheme.titleMedium,
      6 => theme.textTheme.titleSmall,
      _ => theme.textTheme.bodyLarge,
    };
    final merged = (baseStyle ?? const TextStyle()).merge(headingStyle);

    return Text.rich(
      TextSpan(
        children: buildInlineSpans(
          node.text,
          context,
          baseStyle: merged,
          onLinkTap: onLinkTap,
          recognizers: recognizers,
          latex: latex,
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({
    super.key,
    required this.node,
    required this.recognizers,
    this.baseStyle,
    this.onLinkTap,
    this.latex = false,
  });

  final ParagraphNode node;
  final TextStyle? baseStyle;
  final List<GestureRecognizer> recognizers;
  final void Function(Uri uri)? onLinkTap;
  final bool latex;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: buildInlineSpans(
          node.text,
          context,
          baseStyle: baseStyle,
          onLinkTap: onLinkTap,
          recognizers: recognizers,
          latex: latex,
        ),
      ),
    );
  }
}

class _Blockquote extends StatelessWidget {
  const _Blockquote({
    super.key,
    required this.node,
    required this.recognizers,
    this.baseStyle,
    this.onLinkTap,
    this.latex = false,
  });

  final BlockquoteNode node;
  final TextStyle? baseStyle;
  final List<GestureRecognizer> recognizers;
  final void Function(Uri uri)? onLinkTap;
  final bool latex;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: <Widget>[
          for (final child in node.children) _renderInner(context, child),
        ],
      ),
    );
  }

  Widget _renderInner(BuildContext context, AstNode child) {
    return switch (child) {
      ParagraphNode() => _Paragraph(
        key: ValueKey<int>(child.id),
        node: child,
        baseStyle: baseStyle,
        recognizers: recognizers,
        onLinkTap: onLinkTap,
        latex: latex,
      ),
      HeadingNode() => _Heading(
        key: ValueKey<int>(child.id),
        node: child,
        baseStyle: baseStyle,
        recognizers: recognizers,
        onLinkTap: onLinkTap,
        latex: latex,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _List extends StatelessWidget {
  const _List({
    super.key,
    required this.node,
    required this.recognizers,
    this.baseStyle,
    this.onLinkTap,
    this.latex = false,
  });

  final ListNode node;
  final TextStyle? baseStyle;
  final List<GestureRecognizer> recognizers;
  final void Function(Uri uri)? onLinkTap;
  final bool latex;

  @override
  Widget build(BuildContext context) {
    final start = node.startNumber ?? 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: <Widget>[
        for (var i = 0; i < node.items.length; i++)
          _ListItem(
            key: ValueKey<int>(node.items[i].id),
            node: node.items[i],
            marker: _markerFor(node, i, start),
            baseStyle: baseStyle,
            recognizers: recognizers,
            onLinkTap: onLinkTap,
            latex: latex,
          ),
      ],
    );
  }

  String _markerFor(ListNode list, int index, int start) {
    final item = list.items[index];
    if (item.isTask) {
      return item.isChecked ? '☑' : '☐';
    }
    return list.ordered ? '${start + index}.' : '•';
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({
    super.key,
    required this.node,
    required this.marker,
    required this.recognizers,
    this.baseStyle,
    this.onLinkTap,
    this.latex = false,
  });

  final ListItemNode node;
  final String marker;
  final TextStyle? baseStyle;
  final List<GestureRecognizer> recognizers;
  final void Function(Uri uri)? onLinkTap;
  final bool latex;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 24, child: Text(marker, textAlign: TextAlign.right)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: <Widget>[
              for (final child in node.children)
                if (child is ParagraphNode)
                  _Paragraph(
                    key: ValueKey<int>(child.id),
                    node: child,
                    baseStyle: baseStyle,
                    recognizers: recognizers,
                    onLinkTap: onLinkTap,
                    latex: latex,
                  )
                else
                  const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}
