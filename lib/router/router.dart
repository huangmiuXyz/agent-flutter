import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:agent/features/chat/chat_page.dart';
import 'package:agent/features/chat/chat_route_page.dart';
import 'package:agent/features/chat/panels/sessions_page.dart';
import 'package:agent/features/editor/editor_page.dart';
import 'package:agent/features/settings/settings_page.dart';
import 'package:agent/layout/main_layout.dart';
import 'package:agent/layout/main_shell.dart';
import 'package:agent/utils/platform.dart';

/// The route paths used throughout the app.
abstract class AppRoutes {
  /// 桌面：聊天主页面；移动端：会话列表 tab。
  static const chat = '/';

  /// 移动端：全屏聊天页（/chat/:sessionId）。
  static const chatSessionPrefix = '/chat';

  /// 移动端：app 内编辑器全屏页。
  static const editor = '/editor';

  static const settings = '/settings';
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
  routes: isMobilePlatform ? _mobileRoutes() : _desktopRoutes(),
);

/// 桌面路由：ShellRoute（MainLayout 窗口壳）内的聊天 + 设置页。
List<RouteBase> _desktopRoutes() => [
  ShellRoute(
    builder: (BuildContext context, GoRouterState state, Widget child) {
      return MainLayout(child: child);
    },
    routes: [
      GoRoute(
        path: AppRoutes.chat,
        builder: (BuildContext context, GoRouterState state) {
          return const ChatPage();
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
];

/// 移动端路由：底部双 tab 壳（会话列表 / 设置）+ 壳外全屏页（聊天 / 编辑器）。
List<RouteBase> _mobileRoutes() => [
  StatefulShellRoute.indexedStack(
    builder: (
      BuildContext context,
      GoRouterState state,
      StatefulNavigationShell navigationShell,
    ) {
      return MainShell(navigationShell: navigationShell);
    },
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.chat,
            builder: (BuildContext context, GoRouterState state) {
              return const SessionsPage();
            },
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.settings,
            builder: (BuildContext context, GoRouterState state) {
              return const SettingsPage();
            },
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: '${AppRoutes.chatSessionPrefix}/:sessionId',
    parentNavigatorKey: _rootNavigatorKey,
    builder: (BuildContext context, GoRouterState state) {
      return ChatRoutePage(
        sessionId: state.pathParameters['sessionId']!,
      );
    },
  ),
  GoRoute(
    path: AppRoutes.editor,
    parentNavigatorKey: _rootNavigatorKey,
    builder: (BuildContext context, GoRouterState state) {
      return const EditorPage();
    },
  ),
];
