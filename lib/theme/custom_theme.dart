import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

export 'app_colors.dart';
export 'app_tokens.dart';

class CustomTheme extends ThemeExtension<CustomTheme> {
  const CustomTheme({
    required this.brightness,
    required this.colors,
    required this.spacing,
    required this.radii,
    required this.shadows,
    required this.typography,
    required this.controls,
  });

  final Brightness brightness;
  final AppColors colors;
  final AppSpacing spacing;
  final AppRadii radii;
  final AppShadows shadows;
  final AppTypography typography;
  final AppControls controls;

  static final light = CustomTheme(
    brightness: Brightness.light,
    colors: AppColors.light,
    spacing: const AppSpacing(),
    radii: AppRadii.defaults(),
    shadows: AppShadows.forBrightness(Brightness.light),
    typography: const AppTypography(),
    controls: const AppControls(),
  );

  static final dark = CustomTheme(
    brightness: Brightness.dark,
    colors: AppColors.dark,
    spacing: const AppSpacing(),
    radii: AppRadii.defaults(),
    shadows: AppShadows.forBrightness(Brightness.dark),
    typography: const AppTypography(),
    controls: const AppControls(),
  );

  static CustomTheme resolve(
    Brightness brightness, {
    Map<AppColorRole, int> colorOverrides = const {},
    FontWeight fontWeight = FontWeight.w400,
  }) {
    final base = brightness == Brightness.dark ? dark : light;
    return base.copyWith(
      colors: base.colors.apply(colorOverrides),
      typography: base.typography.copyWith(bodyWeight: fontWeight),
    );
  }

  static CustomTheme of(BuildContext context) {
    final extension = Theme.of(context).extension<CustomTheme>();
    assert(
      extension != null,
      'CustomTheme is missing from ThemeData.extensions',
    );
    return extension ?? light;
  }

  @override
  CustomTheme copyWith({
    Brightness? brightness,
    AppColors? colors,
    AppSpacing? spacing,
    AppRadii? radii,
    AppShadows? shadows,
    AppTypography? typography,
    AppControls? controls,
  }) => CustomTheme(
    brightness: brightness ?? this.brightness,
    colors: colors ?? this.colors,
    spacing: spacing ?? this.spacing,
    radii: radii ?? this.radii,
    shadows: shadows ?? this.shadows,
    typography: typography ?? this.typography,
    controls: controls ?? this.controls,
  );

  @override
  CustomTheme lerp(covariant CustomTheme? other, double t) {
    if (other == null) return this;
    return CustomTheme(
      brightness: t < 0.5 ? brightness : other.brightness,
      colors: AppColors.lerp(colors, other.colors, t),
      spacing: AppSpacing.lerp(spacing, other.spacing, t),
      radii: AppRadii.lerp(radii, other.radii, t),
      shadows: AppShadows.lerp(shadows, other.shadows, t),
      typography: AppTypography.lerp(typography, other.typography, t),
      controls: AppControls.lerp(controls, other.controls, t),
    );
  }

  // Compatibility aliases for existing feature code. New components should use
  // the grouped semantic API above.
  double get spacingXs => spacing.xs;
  double get spacingSm => spacing.sm;
  double get spacingMd => spacing.md;
  double get spacingLg => spacing.lg;
  double get spacingXl => spacing.xl;
  double get controlHeightSm => controls.smallHeight;
  double get controlHeightMd => controls.mediumHeight;
  double get controlHeightLg => controls.largeHeight;
  BorderRadius get radiusXs => radii.xs;
  BorderRadius get radiusSm => radii.sm;
  BorderRadius get radiusMd => radii.md;
  BorderRadius get radiusFull => radii.full;
  List<BoxShadow> get shadowSm => shadows.small;
  List<BoxShadow> get shadowMd => shadows.medium;
  List<BoxShadow> get shadowLg => shadows.large;
  String get fontFamily => typography.fontFamily;
  double get fontSizeCaption => typography.captionSize;
  double get fontSizeBody => typography.bodySize;
  double get fontSizeSubtitle => typography.subtitleSize;
  double get fontSizeTitle => typography.titleSize;
  double get fontSizeH2 => typography.heading2Size;
  double get fontSizeH1 => typography.heading1Size;
  FontWeight get fontWeight => typography.bodyWeight;
  Color get primary => colors.accent;
  Color get onPrimary => colors.onAccent;
  Color get primaryContainer => colors.accentHover;
  Color get onPrimaryContainer => colors.onAccent;
  Color get secondary => colors.panel;
  Color get onSecondary => colors.textPrimary;
  Color get secondaryContainer => colors.panelElevated;
  Color get onSecondaryContainer => colors.textPrimary;
  Color get tertiary => colors.warning;
  Color get onTertiary => colors.textPrimary;
  Color get tertiaryContainer => colors.hover;
  Color get onTertiaryContainer => colors.textPrimary;
  Color get error => colors.danger;
  Color get onError => colors.onDanger;
  Color get errorContainer => colors.danger.withValues(alpha: 0.18);
  Color get onErrorContainer => colors.danger;
  Color get surface => colors.background;
  Color get onSurface => colors.textPrimary;
  Color get onSurfaceVariant => colors.textSecondary;
  Color get surfaceContainerLow => colors.panel;
  Color get surfaceContainer => colors.panelElevated;
  Color get surfaceContainerHigh => colors.hover;
  Color get surfaceContainerHighest => colors.selected;
  Color get outline => colors.border;
  Color get outlineVariant => colors.borderSubtle;
  Color get shadow => colors.shadow;
  Color get scrim => colors.overlay;
  Color get inverseSurface => colors.textPrimary;
  Color get onInverseSurface => colors.background;
  Color get inversePrimary => colors.accentHover;
}
