import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:agent/src/rust/frb_generated.dart';

import 'app.dart';

void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await RustLib.init();

      // 初始化 MCP Toolkit，让 AI 可以查看 Widget 树、截图、交互等
      MCPToolkitBinding.instance
        ..initialize()
        ..initializeFlutterToolkit();

      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(1200, 900),
        minimumSize: Size(400, 300),
        center: true,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      runApp(const ProviderScope(child: AgentApp()));
    },
    (error, stack) {
      MCPToolkitBinding.instance.handleZoneError(error, stack);
    },
  );
}
