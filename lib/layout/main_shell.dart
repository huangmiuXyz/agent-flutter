/// 移动端主外壳 — 底部双 Tab（会话列表 / 设置）+ 全屏聊天/编辑器路由的宿主。
///
/// 由 router.dart 的 StatefulShellRoute 构建，仅移动端使用；
/// 桌面端仍走 MainLayout（ShellRoute）。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:agent/layout/main_layout.dart' show StartupSkillsScan;
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/notification/stream_completion_notifications.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        // 底部安全区由 NavigationBar 自行处理
        bottom: false,
        child: Stack(
          children: [
            navigationShell,
            const StartupSkillsScan(),
            const StreamCompletionNotifications(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // 再次点击当前 tab 回到该分支首页
          initialLocation: index == navigationShell.currentIndex,
        ),
        height: 64,
        backgroundColor: custom.colors.panel,
        indicatorColor: custom.colors.accent.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.messageSquare),
            selectedIcon: Icon(LucideIcons.messageSquare),
            label: '会话',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.settings),
            selectedIcon: Icon(LucideIcons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
