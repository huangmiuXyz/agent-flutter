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
    ColorScheme? lightColorScheme,
    ColorScheme? darkColorScheme,
    Color? scaffoldBackgroundColor,
    @Default(200) int iconThickness,
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

  void setLightColorScheme(ColorScheme scheme) {
    state = state.copyWith(lightColorScheme: scheme);
  }

  void setDarkColorScheme(ColorScheme scheme) {
    state = state.copyWith(darkColorScheme: scheme);
  }

  void setScaffoldBackgroundColor(Color color) {
    state = state.copyWith(scaffoldBackgroundColor: color);
  }

  void resetColorScheme() {
    state = state.copyWith(
      lightColorScheme: null,
      darkColorScheme: null,
      scaffoldBackgroundColor: null,
    );
  }

  void setIconThickness(int v) {
    state = state.copyWith(iconThickness: v);
  }

  void resetScaffoldBackgroundColor() {
    state = state.copyWith(scaffoldBackgroundColor: null);
  }
}
