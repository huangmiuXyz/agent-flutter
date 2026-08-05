// Public Streamdown widget.
//
// Two construction modes:
//   * `Streamdown(stream: ...)` — incremental rendering of a token stream
//     emitting markdown chunks (typical AI chat use case).
//   * `Streamdown.text(...)` — render a complete markdown string in one shot.
//
// Both modes share the same incremental path internally; the static
// constructor just feeds the entire string and immediately completes.

import 'dart:async';

import 'package:flutter/material.dart';

import '../parser/parser.dart';
import '../parser/tokenizer.dart';
import 'ast_renderer.dart';
import 'syntax_theme.dart';

/// Flicker-free streaming markdown widget.
///
/// Drop-in replacement for `flutter_markdown` that handles partial code
/// fences, half-finished tables, and mid-stream inline formatting without
/// re-parsing the prefix on every chunk.
class Streamdown extends StatefulWidget {
  /// Streaming constructor — render markdown as chunks arrive on [stream].
  ///
  /// Chunks are append-only: each event should be the **new** text since the
  /// previous event, not a cumulative buffer. This matches OpenAI / Anthropic
  /// / Gemini SDK conventions.
  const Streamdown({
    super.key,
    required Stream<String> stream,
    this.textStyle,
    this.selectable = true,
    this.onLinkTap,
    this.padding,
    this.syntaxTheme,
    this.codeBlockBuilder,
    this.latex = false,
    this.errorBuilder,
  }) : _stream = stream,
       _text = null;

  /// Static constructor — render a complete markdown string. Uses the same
  /// incremental parser internally.
  const Streamdown.text(
    String text, {
    super.key,
    this.textStyle,
    this.selectable = true,
    this.onLinkTap,
    this.padding,
    this.syntaxTheme,
    this.codeBlockBuilder,
    this.latex = false,
    this.errorBuilder,
  }) : _stream = null,
       _text = text;

  final Stream<String>? _stream;
  final String? _text;

  /// Base text style for paragraph and inline text. Headings layer on the
  /// theme's textTheme above this.
  final TextStyle? textStyle;

  /// When true (default), the rendered text is selectable via
  /// [SelectionArea]. Set to false for tap-through layouts.
  final bool selectable;

  /// Called when a link or autolink is tapped.
  final void Function(Uri uri)? onLinkTap;

  /// Optional padding around the rendered document.
  final EdgeInsetsGeometry? padding;

  /// Override the syntax-highlight color scheme for fenced code blocks.
  /// Defaults to [SyntaxTheme.auto] (follows ambient brightness).
  final SyntaxTheme? syntaxTheme;

  /// Full override for code block rendering. When non-null, this is called
  /// instead of the default [CodeBlockWidget] for every fenced code block.
  /// Useful for line numbers, custom themes, or non-standard layouts.
  final CodeBlockBuilder? codeBlockBuilder;

  /// When true, `$...$` is rendered as inline LaTeX math and `$$...$$` as
  /// block math via the `flutter_math_fork` package. Defaults to false so
  /// dollar amounts (`$10`, `$20`) don't get treated as math.
  final bool latex;

  /// Called when the input stream emits an error. Returning null falls back
  /// to silently dropping the error.
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )?
  errorBuilder;

  @override
  State<Streamdown> createState() => _StreamdownState();
}

class _StreamdownState extends State<Streamdown> {
  late Tokenizer _tokenizer;
  late Parser _parser;
  StreamSubscription<String>? _sub;
  Object? _streamError;
  StackTrace? _streamStack;

  @override
  void initState() {
    super.initState();
    _initPipeline();
  }

  @override
  void didUpdateWidget(covariant Streamdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    final streamChanged = widget._stream != oldWidget._stream;
    final textChanged = widget._text != oldWidget._text;
    if (streamChanged || textChanged) {
      _sub?.cancel();
      _initPipeline();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _initPipeline() {
    _tokenizer = Tokenizer();
    _parser = Parser();
    _streamError = null;
    _streamStack = null;
    final text = widget._text;
    if (text != null) {
      _consume(text);
      _completeStream();
      return;
    }
    final stream = widget._stream;
    if (stream != null) {
      _sub = stream.listen(
        _consume,
        onDone: _completeStream,
        onError: _onStreamError,
        cancelOnError: false,
      );
    }
  }

  void _onStreamError(Object error, StackTrace stack) {
    if (!mounted) return;
    setState(() {
      _streamError = error;
      _streamStack = stack;
    });
  }

  void _consume(String chunk) {
    _parser.feed(_tokenizer.feed(chunk));
    // Provisional rendering: the unfinished trailing line (no newline yet)
    // is rendered immediately and replaced as it grows, so streaming content
    // is visible without waiting for a newline / stream end.
    final pending = _tokenizer.pendingLine;
    if (pending.isNotEmpty) {
      _parser.feedProvisional(pending);
    }
    if (mounted) setState(() {});
  }

  void _completeStream() {
    _parser.feed(_tokenizer.complete());
    _parser.complete();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_streamError != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(context, _streamError!, _streamStack);
    }
    final renderer = AstRenderer(
      document: _parser.document,
      textStyle: widget.textStyle,
      onLinkTap: widget.onLinkTap,
      syntaxTheme: widget.syntaxTheme ?? SyntaxTheme.auto(context),
      codeBlockBuilder: widget.codeBlockBuilder,
      latex: widget.latex,
    );
    final padded = widget.padding != null
        ? Padding(padding: widget.padding!, child: renderer)
        : renderer;
    return widget.selectable ? SelectionArea(child: padded) : padded;
  }
}
