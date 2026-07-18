import 'package:flutter/material.dart';

import 'custom_theme.dart';

@immutable
class ThemeSettings {
  const ThemeSettings({
    this.themeMode = ThemeMode.system,
    this.presetId = 'default',
    this.fontWeightValue = 400,
    this.lightOverrides = const {},
    this.darkOverrides = const {},
  });

  final ThemeMode themeMode;
  final String presetId;
  final int fontWeightValue;
  final Map<AppColorRole, int> lightOverrides;
  final Map<AppColorRole, int> darkOverrides;

  bool get hasColorOverrides =>
      lightOverrides.isNotEmpty || darkOverrides.isNotEmpty;

  /// Maps [fontWeightValue] back to a [FontWeight].
  /// Falls back to [FontWeight.w400] if the value doesn't match any
  /// predefined weight.
  FontWeight get fontWeight {
    if (fontWeightValue <= 100) return FontWeight.w100;
    if (fontWeightValue <= 200) return FontWeight.w200;
    if (fontWeightValue <= 300) return FontWeight.w300;
    if (fontWeightValue <= 400) return FontWeight.w400;
    if (fontWeightValue <= 500) return FontWeight.w500;
    if (fontWeightValue <= 600) return FontWeight.w600;
    if (fontWeightValue <= 700) return FontWeight.w700;
    if (fontWeightValue <= 800) return FontWeight.w800;
    return FontWeight.w900;
  }

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    String? presetId,
    int? fontWeightValue,
    Map<AppColorRole, int>? lightOverrides,
    Map<AppColorRole, int>? darkOverrides,
  }) => ThemeSettings(
    themeMode: themeMode ?? this.themeMode,
    presetId: presetId ?? this.presetId,
    fontWeightValue: fontWeightValue ?? this.fontWeightValue,
    lightOverrides: lightOverrides ?? this.lightOverrides,
    darkOverrides: darkOverrides ?? this.darkOverrides,
  );
}

extension ThemeSettingsResolution on ThemeSettings {
  CustomTheme get effectiveLight => CustomTheme.resolve(
    Brightness.light,
    colorOverrides: lightOverrides,
    fontWeight: fontWeight,
  );

  CustomTheme get effectiveDark => CustomTheme.resolve(
    Brightness.dark,
    colorOverrides: darkOverrides,
    fontWeight: fontWeight,
  );

  CustomTheme effectiveFor(Brightness brightness) =>
      brightness == Brightness.dark ? effectiveDark : effectiveLight;
}
