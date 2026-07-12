import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/theme/provider.dart';
import 'package:agent/theme/theme_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeSettings', () {
    test('round-trips serializable user settings', () {
      final settings = ThemeSettings(
        themeMode: ThemeMode.dark,
        iconThickness: 500,
        fontWeightValue: 600,
        lightOverrides: {
          AppColorRole.accent: const Color(0xFF123456).toARGB32(),
        },
      );

      final decoded = ThemeSettings.fromJson(settings.toJson());

      expect(decoded.themeMode, ThemeMode.dark);
      expect(decoded.iconThickness, 500);
      expect(decoded.fontWeight, FontWeight.w600);
      expect(
        decoded.lightOverrides[AppColorRole.accent],
        const Color(0xFF123456).toARGB32(),
      );
    });

    test('ignores unknown color roles for forward compatibility', () {
      final decoded = ThemeSettings.fromJson({
        'lightOverrides': {'futureRole': 0xFFFFFFFF},
      });

      expect(decoded.lightOverrides, isEmpty);
    });
  });

  group('Theme provider', () {
    late SharedPreferences preferences;
    late ThemeRepository repository;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      repository = ThemeRepository(preferences);
      container = ProviderContainer(
        overrides: [themeRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    test('resolves forced brightness independently from the platform', () {
      expect(container.read(effectiveBrightnessProvider), Brightness.light);

      container.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);

      expect(container.read(effectiveBrightnessProvider), Brightness.dark);
    });

    test('applies typed color overrides and accessible foreground', () {
      container
          .read(themeProvider.notifier)
          .setColor(
            Brightness.light,
            AppColorRole.accent,
            const Color(0xFFFFFF00),
          );

      final theme = container.read(themeProvider).effectiveLight;
      expect(theme.colors.accent, const Color(0xFFFFFF00));
      expect(theme.colors.onAccent, const Color(0xFF000000));
    });

    test('persists changes through the repository', () async {
      container.read(themeProvider.notifier)
        ..setThemeMode(ThemeMode.dark)
        ..setIconThickness(600)
        ..setFontWeight(FontWeight.w700);
      await Future<void>.delayed(Duration.zero);

      final restored = repository.load();
      expect(restored.themeMode, ThemeMode.dark);
      expect(restored.iconThickness, 600);
      expect(restored.fontWeight, FontWeight.w700);
    });
  });
}
