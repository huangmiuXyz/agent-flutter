// GFM table widget.
//
// Each cell can contain inline markdown (bold, italic, links, inline code).
// Column widths use `IntrinsicColumnWidth` — they grow as wider content
// arrives but never shrink, which gives stable layout during streaming
// (rows added to the body don't cause earlier rows to reflow narrower).
//
// Wide tables wrap in a horizontal `SingleChildScrollView` so they don't
// overflow narrow viewports.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../parser/ast.dart';
import '../parser/token.dart';
import 'inline_spans.dart';

class TableWidget extends StatelessWidget {
  const TableWidget({
    super.key,
    required this.node,
    required this.recognizers,
    this.baseStyle,
    this.onLinkTap,
    this.latex = false,
  });

  final TableNode node;
  final TextStyle? baseStyle;
  final List<GestureRecognizer> recognizers;
  final void Function(Uri uri)? onLinkTap;
  final bool latex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant;
    final headerBg = theme.colorScheme.surfaceContainerHighest;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: borderColor),
        children: <TableRow>[
          TableRow(
            decoration: BoxDecoration(color: headerBg),
            children: <Widget>[
              for (var i = 0; i < node.headers.length; i++)
                _Cell(
                  text: node.headers[i],
                  alignment: _safeAlignment(i),
                  recognizers: recognizers,
                  baseStyle: (baseStyle ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  onLinkTap: onLinkTap,
                  latex: latex,
                ),
            ],
          ),
          for (final row in node.rows)
            TableRow(
              children: <Widget>[
                for (var i = 0; i < node.headers.length; i++)
                  _Cell(
                    text: i < row.length ? row[i] : '',
                    alignment: _safeAlignment(i),
                    recognizers: recognizers,
                    baseStyle: baseStyle,
                    onLinkTap: onLinkTap,
                    latex: latex,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  TableAlignment _safeAlignment(int column) => column < node.alignments.length
      ? node.alignments[column]
      : TableAlignment.none;
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.text,
    required this.alignment,
    required this.recognizers,
    this.baseStyle,
    this.onLinkTap,
    this.latex = false,
  });

  final String text;
  final TableAlignment alignment;
  final TextStyle? baseStyle;
  final List<GestureRecognizer> recognizers;
  final void Function(Uri uri)? onLinkTap;
  final bool latex;

  @override
  Widget build(BuildContext context) {
    final spans = buildInlineSpans(
      text,
      context,
      baseStyle: baseStyle,
      onLinkTap: onLinkTap,
      recognizers: recognizers,
      latex: latex,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: _textAlign(alignment),
      ),
    );
  }

  TextAlign _textAlign(TableAlignment a) => switch (a) {
    TableAlignment.left => TextAlign.left,
    TableAlignment.center => TextAlign.center,
    TableAlignment.right => TextAlign.right,
    TableAlignment.none => TextAlign.start,
  };
}
