import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'custom_theme.dart';
import 'theme_repository.dart';
import 'theme_settings.dart';

export 'theme_settings.dart';

final themeRepositoryProvider = Provider<ThemeRepository>((ref) {
  throw StateError('ThemeRepository must be overridden at startup');
});

class ThemeNotifier extends Notifier<ThemeSettings> {
  late final ThemeRepository _repository;
  Future<void> _saveQueue = Future.value();

  @override
  ThemeSettings build() {
    _repository = ref.watch(themeRepositoryProvider);
    return _repository.load();
  }

  void _update(ThemeSettings next) {
    state = next;
    _saveQueue = _saveQueue.then((_) async {
      try {
        await _repository.save(next);
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'theme settings',
            context: ErrorDescription('while saving theme settings'),
          ),
        );
      }
    });
    unawaited(_saveQueue);
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

final themeProvider = NotifierProvider<ThemeNotifier, ThemeSettings>(
  ThemeNotifier.new,
);

class PlatformBrightnessNotifier extends Notifier<Brightness>
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

final platformBrightnessProvider =
    NotifierProvider<PlatformBrightnessNotifier, Brightness>(
      PlatformBrightnessNotifier.new,
    );

final effectiveBrightnessProvider = Provider<Brightness>((ref) {
  final settings = ref.watch(themeProvider);
  return switch (settings.themeMode) {
    ThemeMode.system => ref.watch(platformBrightnessProvider),
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
  };
});

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
