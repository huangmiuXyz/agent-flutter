import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/theme/provider.dart';
import 'package:agent/theme/theme_repository.dart';
import 'package:agent/widgets/button/app_button.dart';
import 'package:agent/widgets/icon/app_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ThemeRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = ThemeRepository(await SharedPreferences.getInstance());
  });

  testWidgets('AppIcon reads the custom theme instead of ColorScheme', (
    tester,
  ) async {
    const iconColor = Color(0xFFB000B5);
    final theme = CustomTheme.light.copyWith(
      colors: CustomTheme.light.colors.withColor(
        AppColorRole.textPrimary,
        iconColor,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [themeRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: ThemeData(extensions: [theme]),
          home: const AppIcon('settings'),
        ),
      ),
    );

    expect(tester.widget<Icon>(find.byType(Icon)).color, iconColor);
  });

  testWidgets('disabled AppButton uses custom disabled foreground', (
    tester,
  ) async {
    final theme = CustomTheme.light;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [theme]),
        home: AppButton(text: 'Disabled', disabled: true, onPressed: () {}),
      ),
    );

    final text = tester.widget<Text>(find.text('Disabled'));
    expect(text.style?.color, theme.colors.textDisabled);
  });
}
