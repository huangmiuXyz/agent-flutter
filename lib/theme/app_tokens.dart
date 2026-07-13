import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

const String? defaultFontFamily = null;

@immutable
class AppSpacing {
  const AppSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  static AppSpacing lerp(AppSpacing a, AppSpacing b, double t) => AppSpacing(
    xs: lerpDouble(a.xs, b.xs, t)!,
    sm: lerpDouble(a.sm, b.sm, t)!,
    md: lerpDouble(a.md, b.md, t)!,
    lg: lerpDouble(a.lg, b.lg, t)!,
    xl: lerpDouble(a.xl, b.xl, t)!,
  );
}

@immutable
class AppRadii {
  const AppRadii({
    required this.xs,
    required this.sm,
    required this.md,
    required this.full,
  });

  factory AppRadii.defaults() => const AppRadii(
    xs: BorderRadius.all(Radius.circular(4)),
    sm: BorderRadius.all(Radius.circular(8)),
    md: BorderRadius.all(Radius.circular(12)),
    full: BorderRadius.all(Radius.circular(999)),
  );

  final BorderRadius xs;
  final BorderRadius sm;
  final BorderRadius md;
  final BorderRadius full;

  static AppRadii lerp(AppRadii a, AppRadii b, double t) => AppRadii(
    xs: BorderRadius.lerp(a.xs, b.xs, t)!,
    sm: BorderRadius.lerp(a.sm, b.sm, t)!,
    md: BorderRadius.lerp(a.md, b.md, t)!,
    full: BorderRadius.lerp(a.full, b.full, t)!,
  );
}

@immutable
class AppControls {
  const AppControls({
    this.smallHeight = 24,
    this.mediumHeight = 32,
    this.largeHeight = 40,
  });

  final double smallHeight;
  final double mediumHeight;
  final double largeHeight;

  static AppControls lerp(AppControls a, AppControls b, double t) =>
      AppControls(
        smallHeight: lerpDouble(a.smallHeight, b.smallHeight, t)!,
        mediumHeight: lerpDouble(a.mediumHeight, b.mediumHeight, t)!,
        largeHeight: lerpDouble(a.largeHeight, b.largeHeight, t)!,
      );
}

@immutable
class AppTypography {
  const AppTypography({
    this.fontFamily = defaultFontFamily,
    this.captionSize = 12,
    this.bodySize = 14,
    this.subtitleSize = 16,
    this.titleSize = 18,
    this.heading2Size = 24,
    this.heading1Size = 32,
    this.bodyWeight = FontWeight.w400,
  });

  final String? fontFamily;
  final double captionSize;
  final double bodySize;
  final double subtitleSize;
  final double titleSize;
  final double heading2Size;
  final double heading1Size;
  final FontWeight bodyWeight;

  String? get effectiveFontFamily => fontFamily;

  AppTypography copyWith({FontWeight? bodyWeight}) => AppTypography(
    fontFamily: fontFamily,
    captionSize: captionSize,
    bodySize: bodySize,
    subtitleSize: subtitleSize,
    titleSize: titleSize,
    heading2Size: heading2Size,
    heading1Size: heading1Size,
    bodyWeight: bodyWeight ?? this.bodyWeight,
  );

  TextStyle styleForSize(double size, Color color, {FontWeight? weight}) {
    final effectiveWeight = weight ?? bodyWeight;
    return TextStyle(
      color: color,
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: effectiveWeight,
    );
  }

  static AppTypography lerp(AppTypography a, AppTypography b, double t) =>
      AppTypography(
        fontFamily: t < 0.5 ? a.fontFamily : b.fontFamily,
        captionSize: lerpDouble(a.captionSize, b.captionSize, t)!,
        bodySize: lerpDouble(a.bodySize, b.bodySize, t)!,
        subtitleSize: lerpDouble(a.subtitleSize, b.subtitleSize, t)!,
        titleSize: lerpDouble(a.titleSize, b.titleSize, t)!,
        heading2Size: lerpDouble(a.heading2Size, b.heading2Size, t)!,
        heading1Size: lerpDouble(a.heading1Size, b.heading1Size, t)!,
        bodyWeight: t < 0.5 ? a.bodyWeight : b.bodyWeight,
      );
}

@immutable
class AppShadows {
  const AppShadows({
    required this.small,
    required this.medium,
    required this.large,
  });

  factory AppShadows.forBrightness(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return AppShadows(
      small: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.20 : 0.08),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
      medium: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.25 : 0.10),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
      large: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.30 : 0.12),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  final List<BoxShadow> small;
  final List<BoxShadow> medium;
  final List<BoxShadow> large;

  static AppShadows lerp(AppShadows a, AppShadows b, double t) => AppShadows(
    small: BoxShadow.lerpList(a.small, b.small, t)!,
    medium: BoxShadow.lerpList(a.medium, b.medium, t)!,
    large: BoxShadow.lerpList(a.large, b.large, t)!,
  );
}
