import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 禁用引擎层的语义树处理，消除 Windows Accessibility Bridge 刷屏日志
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
}
