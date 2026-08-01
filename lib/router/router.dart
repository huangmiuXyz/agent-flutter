import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:agent/features/chat/chat_page.dart';
import 'package:agent/features/settings/settings_page.dart';
import 'package:agent/dev/demo_page.dart';
import 'package:agent/layout/main_layout.dart';

/// The route paths used throughout the app.
abstract class AppRoutes {
  static const chat = '/';
  static const settings = '/settings';
  static const demo = '/demo';
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// 根 Navigator 的 context。
///
/// 供快捷键层等位于 Navigator 外层（如 MaterialApp.builder）的代码
/// 执行需要 Navigator 的操作（打开弹窗等）。仅在 Navigator 挂载后非 null。
BuildContext? get rootNavigatorContext =>
    _rootNavigatorKey.currentState?.context;

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
            return const ChatDemo();
          },
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (BuildContext context, GoRouterState state) {
            return const SettingsPage();
          },
        ),
        GoRoute(
          path: AppRoutes.demo,
          builder: (BuildContext context, GoRouterState state) {
            return const DemoPage();
          },
        ),
      ],
    ),
  ],
);
