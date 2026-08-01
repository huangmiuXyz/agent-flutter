/// 命令模型 — 对齐 VSCode Command 语义的轻量实现。
///
/// 一条命令 = 标识（id）+ 展示（title/category/icon）+ 键位（shortcut）
///            + 可用性（enabled 谓词）+ 执行（run）。
library;

import 'package:flutter/widgets.dart';

/// 单条命令。
class CommandInfo {
  /// 全局唯一标识，如 `workbench.action.openSettings`。
  final String id;

  /// 展示标题，如「打开设置」。
  final String title;

  /// 分组名（命令面板中按此分组），如「会话」「视图」。
  final String? category;

  /// 命令面板中显示的图标名（[AppIcon] 注册表内的名字）。
  final String? icon;

  /// 绑定的快捷键；在命令面板中显示，并由 [CommandShortcuts] 自动生效。
  final SingleActivator? shortcut;

  /// 可用性谓词（读取信号动态求值）；为 null 表示始终可用。
  final bool Function()? enabled;

  /// 执行入口；[context] 用于打开对话框等需要 BuildContext 的操作。
  final void Function(BuildContext context) run;

  const CommandInfo({
    required this.id,
    required this.title,
    required this.run,
    this.category,
    this.icon,
    this.shortcut,
    this.enabled,
  });

  /// 当前是否可用（未提供谓词时默认可用）。
  bool get isEnabled => enabled?.call() ?? true;
}

/// 将快捷键格式化为平台风格的可读文本（用于命令面板/菜单显示）。
///
/// - macOS：⌘⇧P
/// - 其他：Ctrl+Shift+P
String formatShortcut(SingleActivator activator) {
  final isMac =
      activator.meta && !activator.control; // meta 通常指 macOS Command
  final parts = <String>[];
  if (activator.meta) parts.add(isMac ? '⌘' : 'Meta+');
  if (activator.control) parts.add(isMac ? '^' : 'Ctrl+');
  if (activator.alt) parts.add(isMac ? '⌥' : 'Alt+');
  if (activator.shift) parts.add(isMac ? '⇧' : 'Shift+');
  final label = activator.trigger.keyLabel.toUpperCase();
  parts.add(label.isEmpty ? '?' : label);
  return parts.join();
}
