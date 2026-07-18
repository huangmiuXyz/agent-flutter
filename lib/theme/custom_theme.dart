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
      'CustomTheme is missing from ThemeData.extensions. '
      'Ensure the theme is registered in ThemeData.extensions.',
    );
    // Deliberately throw if extension is null – a missing CustomTheme
    // indicates a misconfigured theme, not a graceful fallback scenario.
    return extension!;
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
}
