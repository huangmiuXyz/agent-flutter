// Code-block widget with syntax highlighting + copy button + horizontal
// scroll. Uses `flutter_highlight` under the hood.
//
// Performance note: re-parses the whole code block on every rebuild.
// Because each block widget is keyed by its AST node ID, only the
// trailing OPEN block actually re-parses during a stream — closed blocks
// are preserved by Flutter's element diff and never rebuild. Per-line
// caching (further optimization) can land in Phase 8.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart' show HighlightView;

import '../parser/ast.dart';
import 'syntax_theme.dart';

class CodeBlockWidget extends StatelessWidget {
  const CodeBlockWidget({
    super.key,
    required this.node,
    required this.syntaxTheme,
    this.builder,
  });

  final CodeBlockNode node;
  final SyntaxTheme syntaxTheme;
  final CodeBlockBuilder? builder;

  @override
  Widget build(BuildContext context) {
    if (builder != null) {
      return builder!(context, node.language, node.content, node.isComplete);
    }

    final theme = Theme.of(context);
    final bg = syntaxTheme.effectiveBackground(
      theme.colorScheme.surfaceContainerHighest,
    );
    final fg = syntaxTheme.effectiveDefaultColor(theme.colorScheme.onSurface);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CodeHeader(language: node.language, code: node.content),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: _CodeBody(
              code: node.content,
              language: node.language,
              syntaxTheme: syntaxTheme,
              defaultColor: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the code with syntax highlighting when a language is provided,
/// or falls back to a plain monospace [Text] otherwise. [HighlightView]
/// throws on a null language, so we only delegate when we have one.
class _CodeBody extends StatelessWidget {
  const _CodeBody({
    required this.code,
    required this.language,
    required this.syntaxTheme,
    required this.defaultColor,
  });

  final String code;
  final String? language;
  final SyntaxTheme syntaxTheme;
  final Color defaultColor;

  @override
  Widget build(BuildContext context) {
    final monoStyle = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const <String>['Courier', 'monospace'],
      fontSize: 13,
      height: 1.45,
      color: defaultColor,
    );
    if (language == null || language!.isEmpty) {
      return Text(code, style: monoStyle);
    }
    return HighlightView(
      code,
      language: language,
      theme: syntaxTheme.classes,
      textStyle: monoStyle,
    );
  }
}

class _CodeHeader extends StatelessWidget {
  const _CodeHeader({required this.language, required this.code});

  final String? language;
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
      child: Row(
        children: <Widget>[
          if (language != null && language!.isNotEmpty)
            Text(
              language!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
          const Spacer(),
          _CopyButton(code: code),
        ],
      ),
    );
  }
}

/// Top-right copy-to-clipboard button. Briefly shows a checkmark after copy.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.code});

  final String code;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  Timer? _resetTimer;

  Future<void> _onTap() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: _copied ? 'Copied' : 'Copy',
      onPressed: widget.code.isEmpty ? null : _onTap,
      icon: Icon(
        _copied ? Icons.check : Icons.content_copy_outlined,
        size: 16,
        color: _copied
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
