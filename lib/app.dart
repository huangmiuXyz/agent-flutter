import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:agent/theme/provider.dart';
import 'package:agent/router/router.dart';
import 'package:agent/theme/app_theme.dart';
import 'package:agent/services/llm/llm_providers.dart';
import 'package:agent/rust_bridge/api.dart' as api;

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

class AgentApp extends ConsumerStatefulWidget {
  const AgentApp({super.key});

  @override
  ConsumerState<AgentApp> createState() => _AgentAppState();
}

class _AgentAppState extends ConsumerState<AgentApp> {
  @override
  void initState() {
    super.initState();
    _initMcp();
  }

  Future<void> _initMcp() async {
    try {
      final configPath = ref.read(configPathProvider);
      final errors = await api.initMcp(configPath: configPath);
      if (errors.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errors.join('\n')),
              duration: const Duration(seconds: 5),
            ),
          );
        });
      }
    } catch (_) {
      // MCP 初始化失败不影响主功能
    }
  }

  @override
  Widget build(BuildContext context) {
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
