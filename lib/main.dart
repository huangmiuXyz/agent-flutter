import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 初始化 MCP Toolkit，让 AI 可以查看 Widget 树、截图、交互等
      // MCP Toolkit 内部会调用 ensureSemantics() 启用语义树，因此必须先初始化
      MCPToolkitBinding.instance
        ..initialize()
        ..initializeFlutterToolkit();

      // 禁用引擎层的语义树处理，消除 Windows Accessibility Bridge 刷屏日志
      // 必须在 MCP Toolkit 初始化之后调用，否则 MCP Toolkit 会重新启用
      ui.PlatformDispatcher.instance.setSemanticsTreeEnabled(false);
      ui.PlatformDispatcher.instance.onSemanticsEnabledChanged = () {};

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
