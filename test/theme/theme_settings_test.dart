import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/theme/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeSettings', () {
    test('copies runtime settings without mutating the source', () {
      const settings = ThemeSettings();

      final updated = settings.copyWith(
        themeMode: ThemeMode.dark,
        fontWeightValue: 600,
      );

      expect(settings.themeMode, ThemeMode.system);
      expect(updated.themeMode, ThemeMode.dark);
      expect(updated.fontWeight, FontWeight.w600);
    });

    test('uses the default font family', () {
      const typography = AppTypography(bodyWeight: FontWeight.w400);

      final style = typography.styleForSize(
        18,
        Colors.black,
        weight: FontWeight.w600,
      );

      expect(style.fontFamily, 'JetBrainsMono');
    });
  });

  group('Theme provider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('resolves forced brightness independently from the platform', () {
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

    test('resetAll restores in-memory defaults', () {
      container.read(themeProvider.notifier)
        ..setThemeMode(ThemeMode.dark)
        ..resetAll();

      expect(container.read(themeProvider).themeMode, ThemeMode.system);
    });
  });
}
