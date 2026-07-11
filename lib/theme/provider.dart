import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'custom_theme.dart';

part 'provider.freezed.dart';
part 'provider.g.dart';

@freezed
sealed class ThemeConfig with _$ThemeConfig {
  const factory ThemeConfig({
    @Default(ThemeMode.system) ThemeMode themeMode,
    CustomTheme? lightCustomTheme,
    CustomTheme? darkCustomTheme,
    @Default(300) int iconThickness,
    @Default(FontWeight.w400) FontWeight terminalFontWeight,
  }) = _ThemeConfig;
}

extension ThemeConfigX on ThemeConfig {
  CustomTheme get effectiveLight => lightCustomTheme ?? CustomTheme.light;
  CustomTheme get effectiveDark => darkCustomTheme ?? CustomTheme.dark;

  Brightness resolveBrightness() {
    if (themeMode == ThemeMode.system) {
      return PlatformDispatcher.instance.platformBrightness;
    }
    return themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light;
  }

  CustomTheme effectiveFor(Brightness brightness) =>
      brightness == Brightness.dark ? effectiveDark : effectiveLight;
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

  void setIconThickness(int v) {
    state = state.copyWith(iconThickness: v);
  }

  void setTerminalFontWeight(FontWeight w) {
    state = state.copyWith(terminalFontWeight: w);
  }

  void setLightColor(String field, Color c) {
    final base = state.lightCustomTheme ?? CustomTheme.light;
    final onC = c.computeLuminance() > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    state = state.copyWith(
      lightCustomTheme: _applyColor(base, field, c, onC),
    );
  }

  void setDarkColor(String field, Color c) {
    final base = state.darkCustomTheme ?? CustomTheme.dark;
    final onC = c.computeLuminance() > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    state = state.copyWith(
      darkCustomTheme: _applyColor(base, field, c, onC),
    );
  }

  void resetCustomTheme() {
    state = state.copyWith(
      lightCustomTheme: null,
      darkCustomTheme: null,
    );
  }

  CustomTheme _applyColor(CustomTheme base, String field, Color c, Color onC) {
    return switch (field) {
      'primary' => base.copyWith(primary: c, onPrimary: onC),
      'onPrimary' => base.copyWith(onPrimary: c),
      'primaryContainer' => base.copyWith(primaryContainer: c, onPrimaryContainer: onC),
      'onPrimaryContainer' => base.copyWith(onPrimaryContainer: c),
      'secondary' => base.copyWith(secondary: c, onSecondary: onC),
      'onSecondary' => base.copyWith(onSecondary: c),
      'secondaryContainer' => base.copyWith(secondaryContainer: c, onSecondaryContainer: onC),
      'onSecondaryContainer' => base.copyWith(onSecondaryContainer: c),
      'tertiary' => base.copyWith(tertiary: c, onTertiary: onC),
      'onTertiary' => base.copyWith(onTertiary: c),
      'tertiaryContainer' => base.copyWith(tertiaryContainer: c, onTertiaryContainer: onC),
      'onTertiaryContainer' => base.copyWith(onTertiaryContainer: c),
      'error' => base.copyWith(error: c, onError: onC),
      'onError' => base.copyWith(onError: c),
      'errorContainer' => base.copyWith(errorContainer: c, onErrorContainer: onC),
      'onErrorContainer' => base.copyWith(onErrorContainer: c),
      'surface' => base.copyWith(surface: c, onSurface: onC),
      'onSurface' => base.copyWith(onSurface: c),
      'surfaceContainerHighest' => base.copyWith(surfaceContainerHighest: c),
      'surfaceContainerHigh' => base.copyWith(surfaceContainerHigh: c),
      'surfaceContainer' => base.copyWith(surfaceContainer: c),
      'surfaceContainerLow' => base.copyWith(surfaceContainerLow: c),
      'onSurfaceVariant' => base.copyWith(onSurfaceVariant: c),
      'outline' => base.copyWith(outline: c),
      'outlineVariant' => base.copyWith(outlineVariant: c),
      'shadow' => base.copyWith(shadow: c),
      'scrim' => base.copyWith(scrim: c),
      'inverseSurface' => base.copyWith(inverseSurface: c, onInverseSurface: onC),
      'onInverseSurface' => base.copyWith(onInverseSurface: c),
      'inversePrimary' => base.copyWith(inversePrimary: c),
      _ => base,
    };
  }
}
