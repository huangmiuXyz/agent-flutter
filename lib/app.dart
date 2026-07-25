import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:window_manager/window_manager.dart';

import 'package:agent/store/theme_store.dart';
import 'package:agent/router/router.dart';
import 'package:agent/theme/app_theme.dart';

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
      builder: (context, child) => VirtualWindowFrameInit()(context, child),
    );
  }
}
