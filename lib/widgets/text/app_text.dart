import 'package:flutter/material.dart';

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
    final custom = CustomTheme.of(context);

    return Text(
      data,
      style: TextStyle(
        fontSize: switch (variant) {
          AppTextVariant.caption => custom.fontSizeCaption,
          AppTextVariant.body => custom.fontSizeBody,
          AppTextVariant.subtitle => custom.fontSizeSubtitle,
          AppTextVariant.title => custom.fontSizeTitle,
          AppTextVariant.h2 => custom.fontSizeH2,
          AppTextVariant.h1 => custom.fontSizeH1,
        },
        fontFamily: custom.fontFamily,
      ).merge(style).copyWith(color: color ?? Theme.of(context).colorScheme.onSurface),
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}
