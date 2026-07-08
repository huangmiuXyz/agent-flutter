import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:agent/theme/provider.dart';
import 'package:agent/router/router.dart';
import 'package:agent/theme/app_theme.dart';

class AgentApp extends ConsumerWidget {
  const AgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(themeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Agent',
      themeMode: config.themeMode,
      theme: buildAppTheme(config, Brightness.light),
      darkTheme: buildAppTheme(config, Brightness.dark),
      routerConfig: appRouter,
      builder: (context, child) => VirtualWindowFrameInit()(context, child),
    );
  }
}
