import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/features/chat/panels/chat_content.dart';
import 'package:agent/features/chat/panels/left_panel.dart';
import 'package:agent/features/chat/panels/right_panel.dart';
import 'package:agent/features/chat/panels/terminal_panel.dart';
import 'package:agent/widgets/resizebox/resizebox.dart';

/// 是否是从源码直接运行（`flutter run`），而非打包后的 app。
///
/// 通过检查可执行文件路径是否包含 `build/` 来判断：
/// - `flutter run` 构建产物在项目 build/ 目录下 → true
/// - 打包后 app 被安装到别处（如 /Applications/）→ false
bool _isRunningFromSource() {
  try {
    return Platform.resolvedExecutable.contains('/build/');
  } catch (_) {
    return false;
  }
}

/// Chat page layout.
///
/// Left panel | Chat + Terminal | Right panel (性能检测面板)。
/// 右面板在 `flutter run`（debug/release 均显示），打包后隐藏。
class ChatDemo extends HookConsumerWidget {
  const ChatDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_isRunningFromSource()) {
      // 打包后的 app，不显示性能面板
      return _buildTwoPanelLayout();
    }
    return _buildThreePanelLayout();
  }

  Widget _buildThreePanelLayout() {
    return ResizeBox(
      direction: ResizeDirection.left,
      minSize: 180,
      initialSize: 256,
      maxSize: 400,
      // RightPanel on the right side (direction: left → child is on the right)
      child: const RightPanel(),
      other: ResizeBox(
        direction: ResizeDirection.right,
        minSize: 180,
        initialSize: 256,
        maxSize: 400,
        // LeftPanel on the left side (direction: right → child is on the left)
        child: const LeftPanel(),
        other: ResizeBox(
          direction: ResizeDirection.top,
          minSize: 100,
          initialSize: 250,
          maxSize: 500,
          collapseThreshold: 80,
          initialCollapsed: true,
          other: const ChatContent(),
          child: const TerminalPanel(),
        ),
      ),
    );
  }

  Widget _buildTwoPanelLayout() {
    return ResizeBox(
      direction: ResizeDirection.right,
      minSize: 180,
      initialSize: 256,
      maxSize: 400,
      child: const LeftPanel(),
      other: ResizeBox(
        direction: ResizeDirection.top,
        minSize: 100,
        initialSize: 250,
        maxSize: 500,
        collapseThreshold: 80,
        initialCollapsed: true,
        other: const ChatContent(),
        child: const TerminalPanel(),
      ),
    );
  }
}
