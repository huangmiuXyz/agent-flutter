import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:window_manager/window_manager.dart';

import 'package:agent/features/commands/command_shortcuts.dart';
import 'package:agent/features/commands/command_store.dart';
import 'package:agent/features/commands/commands.dart';
import 'package:agent/store/theme_store.dart';
import 'package:agent/router/router.dart';
import 'package:agent/theme/app_theme.dart';
import 'package:agent/utils/platform.dart';

class _NoOverscrollBehavior extends MaterialScrollBehavior {
  const _NoOverscrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

class AgentApp extends HookWidget {
  const AgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = useExistingSignal(ThemeStore.instance.settings);

    // 注册应用全部命令（幂等，重复注册覆盖同 id）
    CommandStore.instance.registerAll(AppCommands.all());

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Agent',
      themeMode: settings.value.themeMode,
      theme: resolveTheme(settings.value, Brightness.light),
      darkTheme: resolveTheme(settings.value, Brightness.dark),
      scrollBehavior: const _NoOverscrollBehavior(),
      // Zero duration: avoid flicker when resolving light/dark theme on startup.
      themeAnimationDuration: Duration.zero,
      routerConfig: appRouter,
      // 快捷键层挂在 Navigator 外层，任意焦点下都能响应命令快捷键
      builder: (context, child) => CommandShortcuts(
        // 虚拟窗口框仅桌面需要；移动端直接透传
        child: isDesktopPlatform
            ? VirtualWindowFrameInit()(context, child)
            : child!,
      ),
    );
  }
}
