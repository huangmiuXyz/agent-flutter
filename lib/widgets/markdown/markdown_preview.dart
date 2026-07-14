import 'dart:async';

import 'package:flutter/material.dart';
import 'package:streamdown/streamdown.dart';

/// Controller for [MarkdownPreview] that supports streaming text append.
///
/// Create one, pass it to [MarkdownPreview], then call [append] for each new
/// chunk of markdown content. Call [done] when the stream is complete.
///
/// ```dart
/// final controller = MarkdownPreviewController();
///
/// @override
/// void initState() {
///   super.initState();
///   controller.append('Initial content...');
/// }
///
/// // Later, when new tokens arrive:
/// controller.append('**more** text');
/// controller.done();
///
/// @override
/// Widget build(BuildContext context) {
///   return MarkdownPreview(controller: controller);
/// }
/// ```
class MarkdownPreviewController {
  final StreamController<String> _controller = StreamController<String>();
  final StringBuffer _buffer = StringBuffer();

  /// The stream that feeds markdown chunks to the widget.
  Stream<String> get stream => _controller.stream;

  /// The full accumulated text so far.
  String get currentText => _buffer.toString();

  /// Whether the controller has been closed.
  bool get isClosed => _controller.isClosed;

  /// Append a chunk of markdown text to the stream.
  void append(String chunk) {
    if (!_controller.isClosed) {
      _buffer.write(chunk);
      _controller.add(chunk);
    }
  }

  /// Signal that no more content will be appended.
  void done() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }

  /// Dispose the controller.
  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

/// Markdown preview widget with streaming append support.
///
/// Uses [streamdown] internally for flicker-free incremental rendering,
/// supporting provisional rendering of partial code fences, tables, and
/// inline formatting without re-parsing the full content on each chunk.
///
/// Provide exactly one of [text], [controller], or [stream]:
/// ```dart
/// // Static content
/// MarkdownPreview(text: '# Hello World')
///
/// // Streaming via controller
/// final ctrl = MarkdownPreviewController();
/// MarkdownPreview(controller: ctrl)
/// ctrl.append('Hello ');
/// ctrl.append('**World**');
/// ctrl.done();
///
/// // Streaming via raw stream
/// MarkdownPreview(stream: myStream)
/// ```
class MarkdownPreview extends StatelessWidget {
  /// Controller for streaming text append.
  final MarkdownPreviewController? controller;

  /// Raw stream of markdown chunks.
  final Stream<String>? stream;

  /// Static markdown text.
  final String? text;

  /// Base text style for paragraph and inline text.
  final TextStyle? textStyle;

  /// Whether the rendered text is selectable. Defaults to true.
  final bool selectable;

  /// Called when a link or autolink is tapped.
  final void Function(Uri uri)? onLinkTap;

  /// Padding around the rendered document.
  final EdgeInsetsGeometry? padding;

  /// Override the syntax-highlight color scheme for fenced code blocks.
  final SyntaxTheme? syntaxTheme;

  /// Full override for code block rendering.
  final CodeBlockBuilder? codeBlockBuilder;

  /// When true, render `$...$` as inline LaTeX and `$$...$$` as block math.
  final bool latex;

  const MarkdownPreview({
    super.key,
    this.controller,
    this.stream,
    this.text,
    this.textStyle,
    this.selectable = true,
    this.onLinkTap,
    this.padding,
    this.syntaxTheme,
    this.codeBlockBuilder,
    this.latex = false,
  }) : assert(
         (controller != null) ^ (stream != null) ^ (text != null),
         'Exactly one of controller, stream, or text must be provided',
       );

  @override
  Widget build(BuildContext context) {
    final effectiveStream = controller?.stream ?? stream;

    if (text != null) {
      return Streamdown.text(
        text!,
        textStyle: textStyle,
        selectable: selectable,
        onLinkTap: onLinkTap,
        padding: padding,
        syntaxTheme: syntaxTheme,
        codeBlockBuilder: codeBlockBuilder,
        latex: latex,
      );
    }

    assert(
      effectiveStream != null,
      'Either text or a stream (via controller or directly) must be provided',
    );

    return Streamdown(
      stream: effectiveStream!,
      textStyle: textStyle,
      selectable: selectable,
      onLinkTap: onLinkTap,
      padding: padding,
      syntaxTheme: syntaxTheme,
      codeBlockBuilder: codeBlockBuilder,
      latex: latex,
    );
  }
}
