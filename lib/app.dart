import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'router/router.dart';
import 'theme/custom_theme.dart';

class AgentApp extends ConsumerWidget {
  const AgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Agent',
      themeMode: ThemeMode.light,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        child = VirtualWindowFrameInit()(context, child);
        return child;
      },
    );
  }
}

final _base = ThemeData(fontFamily: Platform.isMacOS ? 'PingFang SC' : null);

final _lightTheme = _base.copyWith(
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF000000),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF333333),
    onPrimaryContainer: Color(0xFFE0E0E0),
    secondary: Color(0xFFF6F6F6),
    onSecondary: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF000000),
    surfaceContainerHighest: Color(0xFFF5F5F5),
    onSurfaceVariant: Color(0xFF86868B),
    error: Color(0xFFFF3B30),
    onError: Color(0xFFFFFFFF),
  ),
  extensions: [
    CustomTheme.light,
  ],
);

final _darkTheme = _base.copyWith(
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF000000),
    primaryContainer: Color(0xFFE0E0E0),
    onPrimaryContainer: Color(0xFF333333),
    secondary: Color(0xFFA1A1A6),
    onSecondary: Color(0xFF000000),
    surface: Color(0xFF1E1E1E),
    onSurface: Color(0xFFF5F5F7),
    surfaceContainerHighest: Color(0xFF2C2C2E),
    onSurfaceVariant: Color(0xFFA1A1A6),
    error: Color(0xFFFF453A),
    onError: Color(0xFFFFFFFF),
  ),
  extensions: [
    CustomTheme.dark,
  ],
);
