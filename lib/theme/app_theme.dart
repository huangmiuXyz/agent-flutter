import 'package:flutter/material.dart';

import 'package:agent/theme/provider.dart';
import 'package:agent/theme/custom_theme.dart';

final ThemeData _base = ThemeData();

final ThemeData appLightTheme = _base.copyWith(
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF000000),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF333333),
    onPrimaryContainer: Color(0xFFE0E0E0),
    secondary: Color(0xFFF6F6F6),
    onSecondary: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF000000),
    surfaceContainerHighest: Color(0xFFF5F5F5),
    onSurfaceVariant: Color(0xFF86868B),
    error: Color(0xFFFF3B30),
    onError: Color(0xFFFFFFFF),
  ),
  scaffoldBackgroundColor: const Color(0xFFFFFFFF),
  extensions: [
    CustomTheme.light,
  ],
);

final ThemeData appDarkTheme = _base.copyWith(
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF000000),
    primaryContainer: Color(0xFFE0E0E0),
    onPrimaryContainer: Color(0xFF333333),
    secondary: Color(0xFFA1A1A6),
    onSecondary: Color(0xFF000000),
    surface: Color(0xFF1E1E1E),
    onSurface: Color(0xFFF5F5F7),
    surfaceContainerHighest: Color(0xFF2C2C2E),
    onSurfaceVariant: Color(0xFFA1A1A6),
    error: Color(0xFFFF453A),
    onError: Color(0xFFFFFFFF),
  ),
  scaffoldBackgroundColor: const Color(0xFF303121),
  extensions: [
    CustomTheme.dark,
  ],
);

ThemeData buildAppTheme(ThemeConfig config, Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  var theme = isDark ? appDarkTheme : appLightTheme;

  if (config.colorScheme != null &&
      config.colorScheme!.brightness == brightness) {
    theme = (isDark ? appDarkTheme : appLightTheme).copyWith(
      colorScheme: config.colorScheme,
    );
  }

  if (config.scaffoldBackgroundColor != null) {
    theme = theme.copyWith(
      scaffoldBackgroundColor: config.scaffoldBackgroundColor,
    );
  }

  return theme;
}
