import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'custom_theme.dart';
import 'theme_settings.dart';

export 'theme_settings.dart';

part 'provider.g.dart';

@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  ThemeSettings build() => const ThemeSettings();

  void _update(ThemeSettings next) {
    state = next;
  }

  void toggle() {
    final brightness = ref.read(effectiveBrightnessProvider);
    setThemeMode(
      brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  void setThemeMode(ThemeMode mode) => _update(state.copyWith(themeMode: mode));

  void setIconThickness(int value) =>
      _update(state.copyWith(iconThickness: value.clamp(0, 600)));

  void setFontWeight(FontWeight weight) =>
      _update(state.copyWith(fontWeightValue: weight.value));

  void setColor(Brightness brightness, AppColorRole role, Color color) {
    final source = brightness == Brightness.dark
        ? state.darkOverrides
        : state.lightOverrides;
    final overrides = Map<AppColorRole, int>.of(source)
      ..[role] = color.toARGB32();

    if (role == AppColorRole.accent || role == AppColorRole.danger) {
      final foregroundRole = role == AppColorRole.accent
          ? AppColorRole.onAccent
          : AppColorRole.onDanger;
      overrides[foregroundRole] = _bestForeground(color).toARGB32();
    }

    _update(
      brightness == Brightness.dark
          ? state.copyWith(darkOverrides: Map.unmodifiable(overrides))
          : state.copyWith(lightOverrides: Map.unmodifiable(overrides)),
    );
  }

  void resetColors({Brightness? brightness}) {
    if (brightness == Brightness.light) {
      _update(state.copyWith(lightOverrides: const {}));
    } else if (brightness == Brightness.dark) {
      _update(state.copyWith(darkOverrides: const {}));
    } else {
      _update(
        state.copyWith(lightOverrides: const {}, darkOverrides: const {}),
      );
    }
  }

  void resetAll() => _update(const ThemeSettings());

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

@riverpod
Brightness effectiveBrightness(Ref ref) {
  final settings = ref.watch(themeProvider);
  return switch (settings.themeMode) {
    ThemeMode.system => ref.watch(platformBrightnessProvider),
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
  };
}

@riverpod
class PlatformBrightness extends _$PlatformBrightness
    with WidgetsBindingObserver {
  @override
  Brightness build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  void didChangePlatformBrightness() {
    state = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }
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
