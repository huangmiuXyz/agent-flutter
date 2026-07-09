import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/theme/provider.dart';

ThemeData _buildTheme(
  Brightness brightness,
  CustomTheme defaultCustom,
  CustomTheme? override,
) {
  final custom = override ?? defaultCustom;
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: custom.surface,
    extensions: [custom],
  );
}

final appLightTheme = _buildTheme(
  Brightness.light,
  CustomTheme.light,
  null,
);

final appDarkTheme = _buildTheme(
  Brightness.dark,
  CustomTheme.dark,
  null,
);

ThemeData resolveTheme(ThemeConfig config, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return _buildTheme(
    brightness,
    isDark ? CustomTheme.dark : CustomTheme.light,
    isDark ? config.darkCustomTheme : config.lightCustomTheme,
  );
}
