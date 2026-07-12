import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'theme/provider.dart';
import 'theme/theme_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final themeRepository = ThemeRepository(preferences);

  const windowOptions = WindowOptions(
    size: Size(1200, 900),
    minimumSize: Size(400, 300),
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    ProviderScope(
      overrides: [themeRepositoryProvider.overrideWithValue(themeRepository)],
      child: const AgentApp(),
    ),
  );
}
