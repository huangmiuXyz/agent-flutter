/// 文件系统工具函数
library;

import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:agent/router/router.dart';
import 'package:agent/store/code_forge_store.dart';
import 'package:agent/utils/platform.dart';

/// 在编辑器子窗口中打开文件。
///
/// 对于 JSON 等代码文件，会在应用内编辑器（code_forge）中打开，
/// 而非系统默认应用。
void openFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    debugPrint('openFile: 文件不存在 -> $path');
    return;
  }

  // 更新 store → 写文件 → 广播到其他窗口
  CodeForgeStore.instance.open(path);

  // 确保编辑器窗口已存在或可见（仅桌面支持多窗口）
  if (isDesktopPlatform) {
    _ensureEditorWindow(path);
  } else {
    // 移动端：跳转 app 内编辑器全屏路由（EditorPage 监听 store 切换文件）
    final ctx = rootNavigatorContext;
    if (ctx != null) {
      ctx.push(AppRoutes.editor);
    }
  }
}

Future<void> _ensureEditorWindow(String path) async {
  try {
    final all = await WindowController.getAll();
    final editor = all.where((w) => w.arguments.startsWith('editor:')).toList();
    if (editor.isEmpty) {
      // 尚无编辑器窗口 → 创建并显示
      final w = await WindowController.create(
        WindowConfiguration(
          arguments: 'editor:$path',
          hiddenAtLaunch: true,
        ),
      );
      await w.show();
    } else {
      // 已存在编辑器窗口 → 只更新当前文件（CodeForgeStore.open 已写路径），
      // 并将已隐藏的窗口重新提到前台
      final w = editor.first;
      await w.show();
    }
  } catch (e) {
    debugPrint('_ensureEditorWindow 出错: $e');
  }
}
