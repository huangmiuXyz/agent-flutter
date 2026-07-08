import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class CustomTheme extends ThemeExtension<CustomTheme> {
  final double spacingXs;
  final double spacingSm;
  final double spacingMd;
  final double spacingLg;
  final double spacingXl;
  final double controlHeightSm;
  final double controlHeightMd;
  final double controlHeightLg;

  final BorderRadius radiusXs;
  final BorderRadius radiusSm;
  final BorderRadius radiusMd;
  final BorderRadius radiusFull;

  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowLg;

  final String fontFamily;
  final double fontSizeCaption;
  final double fontSizeBody;
  final double fontSizeSubtitle;
  final double fontSizeTitle;
  final double fontSizeH2;
  final double fontSizeH1;

  const CustomTheme({
    required this.spacingXs,
    required this.spacingSm,
    required this.spacingMd,
    required this.spacingLg,
    required this.spacingXl,
    required this.controlHeightSm,
    required this.controlHeightMd,
    required this.controlHeightLg,
    required this.radiusXs,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusFull,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
    required this.fontFamily,
    required this.fontSizeCaption,
    required this.fontSizeBody,
    required this.fontSizeSubtitle,
    required this.fontSizeTitle,
    required this.fontSizeH2,
    required this.fontSizeH1,
  });

  static CustomTheme _withShadows({
    required List<BoxShadow> shadowSm,
    required List<BoxShadow> shadowMd,
    required List<BoxShadow> shadowLg,
  }) {
    return CustomTheme(
      spacingXs: 4,
      spacingSm: 8,
      spacingMd: 16,
      spacingLg: 24,
      spacingXl: 32,
      controlHeightSm: 24,
      controlHeightMd: 32,
      controlHeightLg: 40,
      radiusXs: BorderRadius.all(Radius.circular(4)),
      radiusSm: BorderRadius.all(Radius.circular(8)),
      radiusMd: BorderRadius.all(Radius.circular(12)),
      radiusFull: BorderRadius.all(Radius.circular(999)),
      shadowSm: shadowSm,
      shadowMd: shadowMd,
      shadowLg: shadowLg,
      fontFamily: 'NotoSansSC',
      fontSizeCaption: 12,
      fontSizeBody: 14,
      fontSizeSubtitle: 16,
      fontSizeTitle: 18,
      fontSizeH2: 24,
      fontSizeH1: 32,
    );
  }

  static final light = _withShadows(
    shadowSm: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ],
    shadowMd: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.10),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
    shadowLg: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static final dark = _withShadows(
    shadowSm: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.20),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ],
    shadowMd: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.25),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
    shadowLg: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.30),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static CustomTheme of(BuildContext context) {
    return Theme.of(context).extension<CustomTheme>()!;
  }

  @override
  CustomTheme copyWith({
    double? spacingXs,
    double? spacingSm,
    double? spacingMd,
    double? spacingLg,
    double? spacingXl,
    double? controlHeightSm,
    double? controlHeightMd,
    double? controlHeightLg,
    BorderRadius? radiusXs,
    BorderRadius? radiusSm,
    BorderRadius? radiusMd,
    BorderRadius? radiusFull,
    List<BoxShadow>? shadowSm,
    List<BoxShadow>? shadowMd,
    List<BoxShadow>? shadowLg,
    String? fontFamily,
    double? fontSizeCaption,
    double? fontSizeBody,
    double? fontSizeSubtitle,
    double? fontSizeTitle,
    double? fontSizeH2,
    double? fontSizeH1,
  }) {
    return CustomTheme(
      spacingXs: spacingXs ?? this.spacingXs,
      spacingSm: spacingSm ?? this.spacingSm,
      spacingMd: spacingMd ?? this.spacingMd,
      spacingLg: spacingLg ?? this.spacingLg,
      spacingXl: spacingXl ?? this.spacingXl,
      controlHeightSm: controlHeightSm ?? this.controlHeightSm,
      controlHeightMd: controlHeightMd ?? this.controlHeightMd,
      controlHeightLg: controlHeightLg ?? this.controlHeightLg,
      radiusXs: radiusXs ?? this.radiusXs,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusFull: radiusFull ?? this.radiusFull,
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSizeCaption: fontSizeCaption ?? this.fontSizeCaption,
      fontSizeBody: fontSizeBody ?? this.fontSizeBody,
      fontSizeSubtitle: fontSizeSubtitle ?? this.fontSizeSubtitle,
      fontSizeTitle: fontSizeTitle ?? this.fontSizeTitle,
      fontSizeH2: fontSizeH2 ?? this.fontSizeH2,
      fontSizeH1: fontSizeH1 ?? this.fontSizeH1,
    );
  }

  @override
  CustomTheme lerp(covariant CustomTheme? other, double t) {
    if (other == null) return this;
    return CustomTheme(
      spacingXs: lerpDouble(spacingXs, other.spacingXs, t)!,
      spacingSm: lerpDouble(spacingSm, other.spacingSm, t)!,
      spacingMd: lerpDouble(spacingMd, other.spacingMd, t)!,
      spacingLg: lerpDouble(spacingLg, other.spacingLg, t)!,
      spacingXl: lerpDouble(spacingXl, other.spacingXl, t)!,
      controlHeightSm: lerpDouble(controlHeightSm, other.controlHeightSm, t)!,
      controlHeightMd: lerpDouble(controlHeightMd, other.controlHeightMd, t)!,
      controlHeightLg: lerpDouble(controlHeightLg, other.controlHeightLg, t)!,
      radiusXs: BorderRadius.lerp(radiusXs, other.radiusXs, t)!,
      radiusSm: BorderRadius.lerp(radiusSm, other.radiusSm, t)!,
      radiusMd: BorderRadius.lerp(radiusMd, other.radiusMd, t)!,
      radiusFull: BorderRadius.lerp(radiusFull, other.radiusFull, t)!,
      shadowSm: t < 0.5 ? shadowSm : other.shadowSm,
      shadowMd: t < 0.5 ? shadowMd : other.shadowMd,
      shadowLg: t < 0.5 ? shadowLg : other.shadowLg,
      fontFamily: t < 0.5 ? fontFamily : other.fontFamily,
      fontSizeCaption: lerpDouble(fontSizeCaption, other.fontSizeCaption, t)!,
      fontSizeBody: lerpDouble(fontSizeBody, other.fontSizeBody, t)!,
      fontSizeSubtitle: lerpDouble(fontSizeSubtitle, other.fontSizeSubtitle, t)!,
      fontSizeTitle: lerpDouble(fontSizeTitle, other.fontSizeTitle, t)!,
      fontSizeH2: lerpDouble(fontSizeH2, other.fontSizeH2, t)!,
      fontSizeH1: lerpDouble(fontSizeH1, other.fontSizeH1, t)!,
    );
  }
}
