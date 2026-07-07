import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'router/router.dart';

class AgentApp extends ConsumerWidget {
  const AgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Agent',
      themeMode: ThemeMode.system,
      theme: ThemeData(fontFamily: Platform.isMacOS ? 'PingFang SC' : null),
      routerConfig: appRouter,
      builder: (context, child) {
        child = VirtualWindowFrameInit()(context, child);
        return child;
      },
    );
  }
}
