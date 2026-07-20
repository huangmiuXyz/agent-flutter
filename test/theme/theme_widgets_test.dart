import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/list/app_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        child: MaterialApp(
          theme: ThemeData(extensions: [theme]),
          home: const AppIcon('settings'),
        ),
      ),
    );

    expect(tester.widget<Icon>(find.byType(Icon)).color, iconColor);
  });

  testWidgets('disabled AppPrimaryButton uses custom disabled foreground', (
    tester,
  ) async {
    final theme = CustomTheme.light;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [theme]),
        home: const AppPrimaryButton(
          text: 'Disabled',
          disabled: true,
          onPressed: null,
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Disabled'));
    expect(text.style?.color, theme.colors.textDisabled);
  });

  testWidgets('non-interactive list rows keep normal foreground', (
    tester,
  ) async {
    final theme = CustomTheme.light;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [theme]),
        home: const AppListItem(label: 'Information'),
      ),
    );

    final text = tester.widget<Text>(find.text('Information'));
    expect(text.style?.color, theme.colors.textPrimary);
  });
}
