import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:signals/signals.dart';

import 'package:agent/store/setting_store.dart';
import 'package:agent/theme/app_theme.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/theme/theme_settings.dart';

class ThemeStore {
  static final instance = ThemeStore._();
  ThemeStore._();

  // ── state ──

  final themeMode = signal(ThemeMode.system);
  final fontFamily = signal(kDefaultFontFamily);
  final fontWeightValue = signal(400);
  final fontSizeScale = signal(1.0);
  final lightOverrides = signal(<AppColorRole, int>{});
  final darkOverrides = signal(<AppColorRole, int>{});

  // ── derived ──

  /// 兼容 [resolveTheme] 的完整 [ThemeSettings] 快照
  late final settings = computed(
    () => ThemeSettings(
      themeMode: themeMode.value,
      fontFamily: fontFamily.value,
      fontWeightValue: fontWeightValue.value,
      fontSizeScale: fontSizeScale.value,
      lightOverrides: lightOverrides.value,
      darkOverrides: darkOverrides.value,
    ),
  );

  /// 当前有效亮度模式
  late final effectiveBrightness = computed(() {
    return switch (themeMode.value) {
      ThemeMode.system => _platformBrightness(),
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
    };
  });

  // ── actions ──

  void toggle() {
    setThemeMode(
      effectiveBrightness.value == Brightness.dark
          ? ThemeMode.light
          : ThemeMode.dark,
    );
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    // 同步持久化到 setting.json（跨窗口通过 settingChanged 广播同步）
    SettingStore.instance.setThemeMode(mode);
  }

  void setFontWeight(FontWeight weight) => fontWeightValue.value = weight.value;

  void setFontSizeScale(double scale) {
    fontSizeScale.value = scale;
    // 同步持久化到 setting.json（跨窗口通过 settingChanged 广播同步）
    SettingStore.instance.setFontSizeScale(scale);
  }

  void setColor(Brightness brightness, AppColorRole role, Color color) {
    final overrides = Map<AppColorRole, int>.of(
      brightness == Brightness.dark
          ? darkOverrides.value
          : lightOverrides.value,
    )..[role] = color.toARGB32();

    if (role == AppColorRole.accent || role == AppColorRole.danger) {
      final foregroundRole = role == AppColorRole.accent
          ? AppColorRole.onAccent
          : AppColorRole.onDanger;
      overrides[foregroundRole] = _bestForeground(color).toARGB32();
    }

    if (brightness == Brightness.dark) {
      darkOverrides.value = Map.unmodifiable(overrides);
    } else {
      lightOverrides.value = Map.unmodifiable(overrides);
    }
  }

  void resetColors({Brightness? brightness}) {
    if (brightness != Brightness.dark) lightOverrides.value = {};
    if (brightness != Brightness.light) darkOverrides.value = {};
  }

  void resetAll() {
    setThemeMode(ThemeMode.system);
    fontFamily.value = kDefaultFontFamily;
    fontWeightValue.value = 400;
    fontSizeScale.value = 1.0;
    lightOverrides.value = {};
    darkOverrides.value = {};
  }

  /// 根据亮度解析当前完整的 CustomTheme
  CustomTheme effectiveFor(Brightness brightness) {
    final s = settings.value;
    final overrides = brightness == Brightness.dark
        ? s.darkOverrides
        : s.lightOverrides;
    return CustomTheme.resolve(
      brightness,
      fontFamily: s.fontFamily,
      colorOverrides: overrides,
      fontWeight: s.fontWeight,
      fontSizeScale: s.fontSizeScale,
    );
  }

  // ── helpers ──

  static Brightness _platformBrightness() =>
      PlatformDispatcher.instance.platformBrightness;

  static Color _bestForeground(Color background) {
    const black = Color(0xFF000000);
    const white = Color(0xFFFFFFFF);
    return _contrastRatio(background, black) >=
            _contrastRatio(background, white)
        ? black
        : white;
  }

  static double _contrastRatio(Color a, Color b) {
    final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
    final darker = identical(lighter, a) ? b : a;
    return (lighter.computeLuminance() + 0.05) /
        (darker.computeLuminance() + 0.05);
  }
}
