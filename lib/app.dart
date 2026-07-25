import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:agent/theme/provider.dart';
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

class AgentApp extends ConsumerWidget {
  const AgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(themeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Agent',
      themeMode: config.themeMode,
      theme: resolveTheme(config, Brightness.light),
      darkTheme: resolveTheme(config, Brightness.dark),
      scrollBehavior: const _NoOverscrollBehavior(),
      // Zero duration: avoid flicker when resolving light/dark theme on startup.
      themeAnimationDuration: Duration.zero,
      routerConfig: appRouter,
      builder: (context, child) => VirtualWindowFrameInit()(context, child),
    );
  }
}
