/// streamdown — Flicker-free streaming markdown renderer for Flutter AI apps.
///
/// Drop-in replacement for `flutter_markdown` that handles partial code
/// fences, half-finished tables, and mid-stream LaTeX without re-parsing
/// the prefix on every chunk.
///
/// See https://pub.dev/packages/streamdown for documentation.
library;

export 'src/render/streamdown_widget.dart' show Streamdown;
export 'src/render/syntax_theme.dart' show CodeBlockBuilder, SyntaxTheme;
