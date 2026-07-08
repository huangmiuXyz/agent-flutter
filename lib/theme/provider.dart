import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'provider.freezed.dart';
part 'provider.g.dart';

@freezed
sealed class ThemeConfig with _$ThemeConfig {
  const factory ThemeConfig({
    @Default(ThemeMode.system) ThemeMode themeMode,
    ColorScheme? colorScheme,
    Color? scaffoldBackgroundColor,
  }) = _ThemeConfig;
}

extension ThemeConfigX on ThemeConfig {
  Brightness resolveBrightness() {
    if (themeMode == ThemeMode.system) {
      return PlatformDispatcher.instance.platformBrightness;
    }
    return themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light;
  }
}

@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  ThemeConfig build() => const ThemeConfig();

  void toggle() {
    final brightness = state.resolveBrightness();
    final newMode =
        brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    state = state.copyWith(themeMode: newMode);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setColorScheme(ColorScheme scheme) {
    state = state.copyWith(colorScheme: scheme);
  }

  void setScaffoldBackgroundColor(Color color) {
    state = state.copyWith(scaffoldBackgroundColor: color);
  }

  void resetColorScheme() {
    state = state.copyWith(
      colorScheme: null,
      scaffoldBackgroundColor: null,
    );
  }
}
