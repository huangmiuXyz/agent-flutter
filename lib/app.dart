import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

class AgentApp extends ConsumerWidget {
  const AgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agent',
      themeMode: ThemeMode.system,
      builder: (context, child) {
        child = VirtualWindowFrameInit()(context, child);
        return child;
      },
      home: const Placeholder(),
    );
  }
}
