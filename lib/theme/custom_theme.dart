import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class CustomTheme extends ThemeExtension<CustomTheme> {
  // ── Layout tokens ─────────────────────────────────────────────────
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

  // ── Color tokens ───────────────────────────────────────────────────
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color surface;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color outline;
  final Color outlineVariant;
  final Color shadow;
  final Color scrim;
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color inversePrimary;

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
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.outline,
    required this.outlineVariant,
    required this.shadow,
    required this.scrim,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
  });

  static CustomTheme _create({
    required List<BoxShadow> shadowSm,
    required List<BoxShadow> shadowMd,
    required List<BoxShadow> shadowLg,
    required Color primary,
    required Color onPrimary,
    required Color primaryContainer,
    required Color onPrimaryContainer,
    required Color secondary,
    required Color onSecondary,
    required Color secondaryContainer,
    required Color onSecondaryContainer,
    required Color tertiary,
    required Color onTertiary,
    required Color tertiaryContainer,
    required Color onTertiaryContainer,
    required Color error,
    required Color onError,
    required Color errorContainer,
    required Color onErrorContainer,
    required Color surface,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color surfaceContainerLow,
    required Color surfaceContainer,
    required Color surfaceContainerHigh,
    required Color surfaceContainerHighest,
    required Color outline,
    required Color outlineVariant,
    required Color shadow,
    required Color scrim,
    required Color inverseSurface,
    required Color onInverseSurface,
    required Color inversePrimary,
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
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: shadow,
      scrim: scrim,
      inverseSurface: inverseSurface,
      onInverseSurface: onInverseSurface,
      inversePrimary: inversePrimary,
    );
  }

  static final light = _create(
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
    primary: const Color(0xFF000000),
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFF333333),
    onPrimaryContainer: const Color(0xFFE0E0E0),
    secondary: const Color(0xFFF6F6F6),
    onSecondary: const Color(0xFF000000),
    secondaryContainer: const Color(0xFFEBEBEB),
    onSecondaryContainer: const Color(0xFF000000),
    tertiary: const Color(0xFFCCCCCC),
    onTertiary: const Color(0xFF000000),
    tertiaryContainer: const Color(0xFFE0E0E0),
    onTertiaryContainer: const Color(0xFF000000),
    error: const Color(0xFFFF3B30),
    onError: const Color(0xFFFFFFFF),
    errorContainer: const Color(0xFFFFDAD6),
    onErrorContainer: const Color(0xFF410002),
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF000000),
    onSurfaceVariant: const Color(0xFF86868B),
    surfaceContainerLow: const Color(0xFFF5F5F5),
    surfaceContainer: const Color(0xFFEBEBEB),
    surfaceContainerHigh: const Color(0xFFE0E0E0),
    surfaceContainerHighest: const Color(0xFFD4D4D4),
    outline: const Color(0xFFD4D4D4),
    outlineVariant: const Color(0xFFCAC4D0),
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: const Color(0xFF303030),
    onInverseSurface: const Color(0xFFF5F5F7),
    inversePrimary: const Color(0xFFD4D4D4),
  );

  static final dark = _create(
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
    primary: const Color(0xFFFFFFFF),
    onPrimary: const Color(0xFF000000),
    primaryContainer: const Color(0xFFE0E0E0),
    onPrimaryContainer: const Color(0xFF333333),
    secondary: const Color(0xFFA1A1A6),
    onSecondary: const Color(0xFF000000),
    secondaryContainer: const Color(0xFF262626),
    onSecondaryContainer: const Color(0xFFF5F5F7),
    tertiary: const Color(0xFF333333),
    onTertiary: const Color(0xFFF5F5F7),
    tertiaryContainer: const Color(0xFF404040),
    onTertiaryContainer: const Color(0xFFF5F5F7),
    error: const Color(0xFFFF453A),
    onError: const Color(0xFFFFFFFF),
    errorContainer: const Color(0xFF93000A),
    onErrorContainer: const Color(0xFFFFDAD6),
    surface: const Color(0xFF000000),
    onSurface: const Color(0xFFF5F5F7),
    onSurfaceVariant: const Color(0xFFA1A1A6),
    surfaceContainerLow: const Color(0xFF1A1A1A),
    surfaceContainer: const Color(0xFF262626),
    surfaceContainerHigh: const Color(0xFF333333),
    surfaceContainerHighest: const Color(0xFF404040),
    outline: const Color(0xFF404040),
    outlineVariant: const Color(0xFF49454F),
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: const Color(0xFFF5F5F7),
    onInverseSurface: const Color(0xFF303030),
    inversePrimary: const Color(0xFF333333),
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
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? tertiary,
    Color? onTertiary,
    Color? tertiaryContainer,
    Color? onTertiaryContainer,
    Color? error,
    Color? onError,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? surface,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? surfaceContainerLow,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? outline,
    Color? outlineVariant,
    Color? shadow,
    Color? scrim,
    Color? inverseSurface,
    Color? onInverseSurface,
    Color? inversePrimary,
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
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer:
          onSecondaryContainer ?? this.onSecondaryContainer,
      tertiary: tertiary ?? this.tertiary,
      onTertiary: onTertiary ?? this.onTertiary,
      tertiaryContainer: tertiaryContainer ?? this.tertiaryContainer,
      onTertiaryContainer:
          onTertiaryContainer ?? this.onTertiaryContainer,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorContainer: errorContainer ?? this.errorContainer,
      onErrorContainer: onErrorContainer ?? this.onErrorContainer,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      surfaceContainerLow:
          surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh:
          surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      onInverseSurface: onInverseSurface ?? this.onInverseSurface,
      inversePrimary: inversePrimary ?? this.inversePrimary,
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
      controlHeightSm:
          lerpDouble(controlHeightSm, other.controlHeightSm, t)!,
      controlHeightMd:
          lerpDouble(controlHeightMd, other.controlHeightMd, t)!,
      controlHeightLg:
          lerpDouble(controlHeightLg, other.controlHeightLg, t)!,
      radiusXs: BorderRadius.lerp(radiusXs, other.radiusXs, t)!,
      radiusSm: BorderRadius.lerp(radiusSm, other.radiusSm, t)!,
      radiusMd: BorderRadius.lerp(radiusMd, other.radiusMd, t)!,
      radiusFull: BorderRadius.lerp(radiusFull, other.radiusFull, t)!,
      shadowSm: t < 0.5 ? shadowSm : other.shadowSm,
      shadowMd: t < 0.5 ? shadowMd : other.shadowMd,
      shadowLg: t < 0.5 ? shadowLg : other.shadowLg,
      fontFamily: t < 0.5 ? fontFamily : other.fontFamily,
      fontSizeCaption:
          lerpDouble(fontSizeCaption, other.fontSizeCaption, t)!,
      fontSizeBody: lerpDouble(fontSizeBody, other.fontSizeBody, t)!,
      fontSizeSubtitle:
          lerpDouble(fontSizeSubtitle, other.fontSizeSubtitle, t)!,
      fontSizeTitle: lerpDouble(fontSizeTitle, other.fontSizeTitle, t)!,
      fontSizeH2: lerpDouble(fontSizeH2, other.fontSizeH2, t)!,
      fontSizeH1: lerpDouble(fontSizeH1, other.fontSizeH1, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer:
          Color.lerp(primaryContainer, other.primaryContainer, t)!,
      onPrimaryContainer:
          Color.lerp(onPrimaryContainer, other.onPrimaryContainer, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      secondaryContainer:
          Color.lerp(secondaryContainer, other.secondaryContainer, t)!,
      onSecondaryContainer:
          Color.lerp(onSecondaryContainer, other.onSecondaryContainer, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      onTertiary: Color.lerp(onTertiary, other.onTertiary, t)!,
      tertiaryContainer:
          Color.lerp(tertiaryContainer, other.tertiaryContainer, t)!,
      onTertiaryContainer:
          Color.lerp(onTertiaryContainer, other.onTertiaryContainer, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      errorContainer:
          Color.lerp(errorContainer, other.errorContainer, t)!,
      onErrorContainer:
          Color.lerp(onErrorContainer, other.onErrorContainer, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant:
          Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
      surfaceContainerLow:
          Color.lerp(surfaceContainerLow, other.surfaceContainerLow, t)!,
      surfaceContainer:
          Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceContainerHigh:
          Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t)!,
      surfaceContainerHighest:
          Color.lerp(surfaceContainerHighest, other.surfaceContainerHighest, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant:
          Color.lerp(outlineVariant, other.outlineVariant, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      inverseSurface:
          Color.lerp(inverseSurface, other.inverseSurface, t)!,
      onInverseSurface:
          Color.lerp(onInverseSurface, other.onInverseSurface, t)!,
      inversePrimary:
          Color.lerp(inversePrimary, other.inversePrimary, t)!,
    );
  }
}
