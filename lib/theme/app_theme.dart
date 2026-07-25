import 'package:flutter/material.dart';

import 'custom_theme.dart';
import 'theme_settings.dart';

ThemeData _buildTheme(CustomTheme custom) => ThemeData(
  brightness: custom.brightness,
  scaffoldBackgroundColor: custom.colors.background,
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
  hoverColor: Colors.transparent,
  extensions: [custom],
);

final appLightTheme = _buildTheme(CustomTheme.light);
final appDarkTheme = _buildTheme(CustomTheme.dark);

ThemeData resolveTheme(ThemeSettings settings, Brightness brightness) =>
    _buildTheme(settings.effectiveFor(brightness));
