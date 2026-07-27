import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/chat/panels/chat_content.dart';
import 'package:agent/features/chat/panels/left_panel.dart';
import 'package:agent/features/chat/panels/right_panel.dart';
import 'package:agent/features/chat/panels/terminal_panel.dart';
import 'package:agent/store/xterm_store.dart';
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

/// 终端面板容器 — 监听 [XtermStore.panelExpanded] 信号自动展开。
///
/// 折叠仍由用户拖拽控制（不自动折叠），保持用户手动控制权。
class _ExpandableTerminalPanel extends HookWidget {
  const _ExpandableTerminalPanel({
    required this.other,
    required this.child,
  });

  final Widget other;
  final Widget child;

  static const double _initialSize = 250;
  static const double _minSize = 100;
  static const double _maxSize = 500;

  @override
  Widget build(BuildContext context) {
    // controller 初始折叠，与 ResizeBox 的 initialCollapsed: true 一致
    final controller = useMemoized(
      () => ResizeBoxController(
        initialCollapsed: true,
        initialSize: _initialSize,
      ),
    );
    final expandCount =
        useExistingSignal(XtermStore.instance.expandRequestCount);

    // 监听 expandRequestCount：每次递增都触发展开（无论当前是否已展开）
    useEffect(() {
      if (expandCount.value > 0) {
        controller.expand(_initialSize.clamp(_minSize, _maxSize));
      }
      return null;
    }, [expandCount.value]);

    return ResizeBox(
      controller: controller,
      direction: ResizeDirection.top,
      minSize: _minSize,
      initialSize: _initialSize,
      maxSize: _maxSize,
      collapseThreshold: 80,
      initialCollapsed: true,
      other: other,
      child: child,
    );
  }
}

/// Chat page layout.
///
/// Left panel | Chat + Terminal | Right panel (性能检测面板)。
/// 右面板在 `flutter run`（debug/release 均显示），打包后隐藏。
class ChatDemo extends StatelessWidget {
  const ChatDemo({super.key});

  @override
  Widget build(BuildContext context) {
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
      other: ResizeBox(
        direction: ResizeDirection.right,
        minSize: 180,
        initialSize: 256,
        maxSize: 400,
        other: const _ExpandableTerminalPanel(
          other: ChatContent(),
          child: TerminalPanel(),
        ),
        child: const LeftPanel(),
      ),
      child: const RightPanel(),
    );
  }

  Widget _buildTwoPanelLayout() {
    return ResizeBox(
      direction: ResizeDirection.right,
      minSize: 180,
      initialSize: 256,
      maxSize: 400,
      other: const _ExpandableTerminalPanel(
        other: ChatContent(),
        child: TerminalPanel(),
      ),
      child: const LeftPanel(),
    );
  }
}
