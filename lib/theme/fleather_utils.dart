import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';

/// Creates a [FleatherThemeData] based on the default fallback, with the given
/// [fontFamily] applied to all text styles (paragraphs, headings, lists,
/// quotes, code blocks, and inline code).
///
/// Also applies [strutStyle] if provided.
///
/// [compact] 为 true 时去掉各文本块的上下间距（用于消息编辑等紧凑场景）。
FleatherThemeData buildFleatherTheme(
  BuildContext context, {
  String? fontFamily,
  StrutStyle? strutStyle,
  bool compact = false,
}) {
  final fallback = FleatherThemeData.fallback(context);
  if (fontFamily == null && strutStyle == null && !compact) {
    return fallback;
  }

  // Apply strutStyle first if given
  final base = strutStyle != null
      ? fallback.copyWith(strutStyle: strutStyle)
      : fallback;
  if (fontFamily == null && !compact) return base;

  // Helper to apply fontFamily to a TextBlockTheme
  TextBlockTheme apply(TextBlockTheme t) => TextBlockTheme(
    style: t.style.copyWith(
      fontFamily: fontFamily ?? t.style.fontFamily,
    ),
    spacing: compact ? VerticalSpacing.zero() : t.spacing,
    lineSpacing: compact ? VerticalSpacing.zero() : t.lineSpacing,
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
    paragraph: apply(base.paragraph),
    heading1: apply(base.heading1),
    heading2: apply(base.heading2),
    heading3: apply(base.heading3),
    heading4: apply(base.heading4),
    heading5: apply(base.heading5),
    heading6: apply(base.heading6),
    lists: apply(base.lists),
    quote: apply(base.quote),
    code: apply(base.code),
    horizontalRule: base.horizontalRule,
    strutStyle: base.strutStyle,
  );
}
