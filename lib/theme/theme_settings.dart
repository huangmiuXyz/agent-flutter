import 'package:flutter/material.dart';

import 'app_colors.dart';

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
