/// 应用全部命令的集中定义。
///
/// 各功能模块的命令都汇总在这里，通过 [CommandStore.registerAll]
/// 一次性注册（app.dart 中调用）。命令的 run 需要 BuildContext 时
/// 由调用方（快捷键层/命令面板）传入，例如打开设置弹窗。
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:agent/features/commands/models/command_info.dart';
import 'package:agent/features/commands/widgets/command_palette.dart';
import 'package:agent/layout/main_layout.dart' show showSettingsDialog;
import 'package:agent/store/session_store.dart';
import 'package:agent/store/theme_store.dart';

/// macOS 用 Meta（⌘），其他平台用 Control（Ctrl），对齐项目快捷键习惯。
SingleActivator _key(LogicalKeyboardKey key, {bool shift = false}) {
  final isMac = Platform.isMacOS;
  return SingleActivator(key, meta: isMac, control: !isMac, shift: shift);
}

/// 全部命令（注册顺序即命令面板分组顺序）。
abstract final class AppCommands {
  static List<CommandInfo> all() => [
    // ── 视图 ──
    CommandInfo(
      id: 'workbench.action.showCommands',
      title: '显示命令面板',
      category: '视图',
      icon: 'search',
      shortcut: _key(LogicalKeyboardKey.keyP, shift: true),
      run: (context) => showCommandPalette(context),
    ),
    CommandInfo(
      id: 'workbench.action.openSettings',
      title: '打开设置',
      category: '视图',
      icon: 'settings',
      shortcut: _key(LogicalKeyboardKey.comma),
      run: (context) => showSettingsDialog(context),
    ),
    CommandInfo(
      id: 'view.toggleTheme',
      title: '切换深浅主题',
      category: '视图',
      icon: 'palette',
      shortcut: _key(LogicalKeyboardKey.keyL, shift: true),
      run: (context) => ThemeStore.instance.toggle(),
    ),

    // ── 会话 ──
    CommandInfo(
      id: 'session.new',
      title: '新建会话',
      category: '会话',
      icon: 'plus',
      shortcut: _key(LogicalKeyboardKey.keyN),
      run: (context) {
        SessionStore.instance.createAndOpen();
      },
    ),
    CommandInfo(
      id: 'session.deleteCurrent',
      title: '删除当前会话',
      category: '会话',
      icon: 'trash2',
      shortcut: _key(LogicalKeyboardKey.backspace, shift: true),
      enabled: () => SessionStore.instance.selectedId.value != null,
      run: (context) {
        final sid = SessionStore.instance.selectedId.value;
        if (sid != null) {
          SessionStore.instance.deleteSessions([sid]);
        }
      },
    ),
    CommandInfo(
      id: 'session.stopStreaming',
      title: '停止生成',
      category: '会话',
      icon: 'square',
      shortcut: _key(LogicalKeyboardKey.period),
      enabled: () =>
          SessionStore.instance.streamingSessionIds.value.isNotEmpty,
      run: (context) {
        final sid = SessionStore.instance.selectedId.value;
        if (sid != null) {
          SessionStore.instance.cancelStreaming(sid);
        }
      },
    ),
  ];
}
