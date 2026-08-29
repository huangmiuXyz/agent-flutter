/// 手机样式预览入口 — 在 macOS 窗口里以移动端布局运行。
///
/// 用法：`flutter run -d macos -t lib/main_mobile_preview.dart`
///
/// 通过 `debugDefaultTargetPlatformOverride` 强制 defaultTargetPlatform
/// 返回 android，让 `isMobilePlatform` 分支（底部 tab 壳、单栏聊天、
/// 全屏聊天/编辑器路由）全部生效；窗口尺寸模拟手机竖屏，
/// 便于在电脑上直接调移动端 UI。
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'main.dart' as app;

Future<void> main() async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  // binding 由 app.main() 在它自己的 zone 内初始化（debug 模式为
  // MarionetteBinding），此处不提前初始化，避免 zone/binding 断言；
  // 窗口尺寸延迟到启动完成后设置。
  unawaited(_configureWindow());
  app.main();
}

Future<void> _configureWindow() async {
  await Future<void>.delayed(const Duration(seconds: 1));
  await windowManager.ensureInitialized();
  const size = Size(420, 900);
  await windowManager.setSize(size);
  await windowManager.setMinimumSize(size);
  await windowManager.center();
}