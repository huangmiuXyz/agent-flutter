// SyntaxTheme — light wrapper around `flutter_highlight`'s theme maps.
//
// Use [SyntaxTheme.auto] for a default that follows the ambient brightness.
// Use [SyntaxTheme.githubLight] / [SyntaxTheme.atomOneDark] for a fixed
// theme. Pass any custom `Map<String, TextStyle>` via the constructor for
// full control (e.g., monokai, dracula, your-own-tokens).

import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart'
    show atomOneDarkTheme;
import 'package:flutter_highlight/themes/github.dart' show githubTheme;

/// A syntax-highlight color scheme for fenced code blocks.
class SyntaxTheme {
  const SyntaxTheme({
    required this.classes,
    this.background,
    this.defaultColor,
  });

  /// GitHub-style light theme.
  factory SyntaxTheme.githubLight() => SyntaxTheme(classes: githubTheme);

  /// Atom One Dark theme.
  factory SyntaxTheme.atomOneDark() => SyntaxTheme(classes: atomOneDarkTheme);

  /// Picks light/dark based on `Theme.of(context).brightness`.
  factory SyntaxTheme.auto(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? SyntaxTheme.atomOneDark()
      : SyntaxTheme.githubLight();

  /// Highlight.js class → text style. Keys: `keyword`, `string`, `comment`, etc.
  ///
  /// The `'root'` key carries the default text color and background for the
  /// whole block; both are picked up automatically when null is passed for
  /// [background] and [defaultColor].
  final Map<String, TextStyle> classes;

  /// Override for the code block background. Defaults to `classes['root']`'s
  /// `backgroundColor`.
  final Color? background;

  /// Override for the default text color. Defaults to `classes['root']`'s
  /// `color`.
  final Color? defaultColor;

  /// Effective background color for this theme (resolved from the override
  /// or the `'root'` class style).
  Color effectiveBackground(Color fallback) =>
      background ?? classes['root']?.backgroundColor ?? fallback;

  /// Effective default text color.
  Color effectiveDefaultColor(Color fallback) =>
      defaultColor ?? classes['root']?.color ?? fallback;
}

/// Signature for a custom code-block renderer. Provide one via the
/// [Streamdown] widget's `codeBlockBuilder` parameter to fully replace the
/// default rendering (line numbers, custom themes, etc.).
typedef CodeBlockBuilder =
    Widget Function(
      BuildContext context,
      String? language,
      String code,
      bool isComplete,
    );
