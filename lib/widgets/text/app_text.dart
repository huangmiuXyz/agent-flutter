import 'package:flutter/material.dart';

import 'package:agent/theme/app_tokens.dart';
import 'package:agent/theme/custom_theme.dart';

enum AppTextVariant { caption, body, subtitle, title, h2, h1 }

class AppText extends StatelessWidget {
  final String data;
  final AppTextVariant variant;
  final Color? color;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  const AppText(
    this.data, {
    super.key,
    this.variant = AppTextVariant.body,
    this.color,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CustomTheme.of(context);
    final typography = theme.typography;
    final fontSize = switch (variant) {
      AppTextVariant.caption => typography.captionSize,
      AppTextVariant.body => typography.bodySize,
      AppTextVariant.subtitle => typography.subtitleSize,
      AppTextVariant.title => typography.titleSize,
      AppTextVariant.h2 => typography.heading2Size,
      AppTextVariant.h1 => typography.heading1Size,
    };
    final defaultWeight = switch (variant) {
      AppTextVariant.caption || AppTextVariant.body => typography.bodyWeight,
      AppTextVariant.subtitle => FontWeight.w500,
      AppTextVariant.title ||
      AppTextVariant.h2 ||
      AppTextVariant.h1 => FontWeight.w600,
    };

    return Text(
      data,
      style: TextStyle(fontFamily: defaultFontFamily)
          .merge(
            typography.styleForSize(
              fontSize,
              color ?? theme.colors.textPrimary,
              weight: defaultWeight,
            ),
          )
          .merge(style),
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}
