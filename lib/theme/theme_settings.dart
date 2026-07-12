import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class ThemeSettings {
  const ThemeSettings({
    this.themeMode = ThemeMode.system,
    this.presetId = 'default',
    this.iconThickness = 300,
    this.fontWeightValue = 400,
    this.lightOverrides = const {},
    this.darkOverrides = const {},
  });

  final ThemeMode themeMode;
  final String presetId;
  final int iconThickness;
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
    int? iconThickness,
    int? fontWeightValue,
    Map<AppColorRole, int>? lightOverrides,
    Map<AppColorRole, int>? darkOverrides,
  }) => ThemeSettings(
    themeMode: themeMode ?? this.themeMode,
    presetId: presetId ?? this.presetId,
    iconThickness: iconThickness ?? this.iconThickness,
    fontWeightValue: fontWeightValue ?? this.fontWeightValue,
    lightOverrides: lightOverrides ?? this.lightOverrides,
    darkOverrides: darkOverrides ?? this.darkOverrides,
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'themeMode': themeMode.name,
    'presetId': presetId,
    'iconThickness': iconThickness,
    'fontWeight': fontWeightValue,
    'lightOverrides': _encodeOverrides(lightOverrides),
    'darkOverrides': _encodeOverrides(darkOverrides),
  };

  factory ThemeSettings.fromJson(Map<String, dynamic> json) => ThemeSettings(
    themeMode:
        ThemeMode.values
            .where((mode) => mode.name == json['themeMode'])
            .firstOrNull ??
        ThemeMode.system,
    presetId: json['presetId'] as String? ?? 'default',
    iconThickness: (json['iconThickness'] as num?)?.toInt() ?? 300,
    fontWeightValue: (json['fontWeight'] as num?)?.toInt() ?? 400,
    lightOverrides: _decodeOverrides(json['lightOverrides']),
    darkOverrides: _decodeOverrides(json['darkOverrides']),
  );

  static Map<String, int> _encodeOverrides(Map<AppColorRole, int> source) => {
    for (final entry in source.entries) entry.key.name: entry.value,
  };

  static Map<AppColorRole, int> _decodeOverrides(Object? source) {
    if (source is! Map) return const {};
    final result = <AppColorRole, int>{};
    for (final entry in source.entries) {
      final role = AppColorRole.values
          .where((value) => value.name == entry.key)
          .firstOrNull;
      final color = entry.value;
      if (role != null && color is num) result[role] = color.toInt();
    }
    return Map.unmodifiable(result);
  }
}
