import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:agent/dev/demo_page.dart';
import 'package:agent/features/settings/settings_page.dart';
import 'package:agent/layout/main_layout.dart';

/// The route paths used throughout the app.
abstract class AppRoutes {
  static const chat = '/';
  static const settings = '/settings';
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.chat,
  routes: [
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return MainLayout(child: child);
      },
      routes: [
        GoRoute(
          path: AppRoutes.chat,
          builder: (BuildContext context, GoRouterState state) {
            return const DemoPage();
          },
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (BuildContext context, GoRouterState state) {
            return const SettingsPage();
          },
        ),
      ],
    ),
  ],
);
