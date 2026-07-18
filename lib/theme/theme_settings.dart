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

  FontWeight get fontWeight => FontWeight.values.firstWhere(
    (weight) => weight.value == fontWeightValue,
    orElse: () => FontWeight.w400,
  );

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
