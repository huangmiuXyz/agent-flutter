import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';

/// Creates a [FleatherThemeData] based on the default fallback, with the given
/// [fontFamily] applied to all text styles (paragraphs, headings, lists,
/// quotes, code blocks, and inline code).
///
/// Also applies [strutStyle] if provided.
FleatherThemeData buildFleatherTheme(
  BuildContext context, {
  String? fontFamily,
  StrutStyle? strutStyle,
}) {
  final fallback = FleatherThemeData.fallback(context);
  if (fontFamily == null && strutStyle == null) return fallback;

  // Apply strutStyle first if given
  final base = strutStyle != null
      ? fallback.copyWith(strutStyle: strutStyle)
      : fallback;
  if (fontFamily == null) return base;

  // Helper to apply fontFamily to a TextBlockTheme
  TextBlockTheme _apply(TextBlockTheme t) => TextBlockTheme(
    style: t.style.copyWith(fontFamily: fontFamily),
    spacing: t.spacing,
    lineSpacing: t.lineSpacing,
    decoration: t.decoration,
  );

  return FleatherThemeData(
    bold: base.bold,
    italic: base.italic,
    underline: base.underline,
    strikethrough: base.strikethrough,
    inlineCode: InlineCodeThemeData(
      style: base.inlineCode.style.copyWith(fontFamily: fontFamily),
      heading1: base.inlineCode.heading1?.copyWith(fontFamily: fontFamily),
      heading2: base.inlineCode.heading2?.copyWith(fontFamily: fontFamily),
      heading3: base.inlineCode.heading3?.copyWith(fontFamily: fontFamily),
      backgroundColor: base.inlineCode.backgroundColor,
      radius: base.inlineCode.radius,
    ),
    link: base.link,
    paragraph: _apply(base.paragraph),
    heading1: _apply(base.heading1),
    heading2: _apply(base.heading2),
    heading3: _apply(base.heading3),
    heading4: _apply(base.heading4),
    heading5: _apply(base.heading5),
    heading6: _apply(base.heading6),
    lists: _apply(base.lists),
    quote: _apply(base.quote),
    code: _apply(base.code),
    horizontalRule: base.horizontalRule,
    strutStyle: base.strutStyle,
  );
}
