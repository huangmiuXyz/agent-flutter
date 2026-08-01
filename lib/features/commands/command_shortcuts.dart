/// 应用级快捷键层 — 从命令表自动生成键位绑定。
///
/// 挂在 MaterialApp.builder（Navigator 外层）。用全局 [HardwareKeyboard]
/// 监听在事件派发到焦点链之前拦截命令快捷键，保证任意焦点位置
/// （聊天输入框、终端、列表等）都能响应——富文本编辑器会吞掉
/// Ctrl+B/Ctrl+U，终端会吞掉 Ctrl+J，仅靠焦点链冒泡到不了这里。
///
/// macOS 上 Ctrl 与 ⌘ 修饰键互换匹配：命令绑定 ⌘ 或 Ctrl 都同时接受
/// 两种按法，兼容用户习惯（如「Ctrl+J」与「⌘J」均切换终端）。
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/features/commands/commands.dart';
import 'package:agent/router/router.dart';

class CommandShortcuts extends HookWidget {
  final Widget child;

  const CommandShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      bool onKeyEvent(KeyEvent event) {
        // 只响应首次按下，按住不放不重复触发
        if (event is! KeyDownEvent) return false;
        final keyboard = HardwareKeyboard.instance;
        for (final cmd in AppCommands.all()) {
          final activator = cmd.shortcut;
          if (activator == null || !_matches(activator, event, keyboard)) {
            continue;
          }
          // 本组件位于 MaterialApp.builder（Navigator 外层），build 的
          // context 不含 Navigator；快捷键触发时根 Navigator 已挂载，
          // 统一用其 context 执行命令（打开弹窗等操作需要）
          final ctx = rootNavigatorContext;
          if (ctx != null) {
            cmd.run(ctx);
            return true;
          }
        }
        return false;
      }

      HardwareKeyboard.instance.addHandler(onKeyEvent);
      return () => HardwareKeyboard.instance.removeHandler(onKeyEvent);
    }, []);

    // Focus 仅为无焦点场景提供事件冒泡起点，不抢输入框焦点
    return Focus(autofocus: true, child: child);
  }
}

/// 匹配命令快捷键；macOS 上 ⌘/Ctrl 修饰键互换也匹配。
bool _matches(
  SingleActivator activator,
  KeyEvent event,
  HardwareKeyboard keyboard,
) {
  if (activator.accepts(event, keyboard)) return true;
  if (!Platform.isMacOS || activator.meta == activator.control) return false;
  // 交换 ⌘/Ctrl 后重新匹配（保留 shift/alt）
  final swapped = SingleActivator(
    activator.trigger,
    control: activator.meta,
    meta: activator.control,
    alt: activator.alt,
    shift: activator.shift,
  );
  return swapped.accepts(event, keyboard);
}
