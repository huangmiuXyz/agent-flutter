import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/chat/panels/chat_content.dart';
import 'package:agent/features/chat/panels/left_panel.dart';
import 'package:agent/features/chat/panels/right_panel.dart';
import 'package:agent/features/chat/panels/terminal_panel.dart';
import 'package:agent/features/checkpoints/checkpoint_list.dart';
import 'package:agent/store/checkpoint_store.dart';
import 'package:agent/store/sidebar_store.dart';
import 'package:agent/store/xterm_store.dart';
import 'package:agent/utils/platform.dart';
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
  const _ExpandableTerminalPanel({required this.other, required this.child});

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
    final expandCount = useExistingSignal(
      XtermStore.instance.expandRequestCount,
    );

    // 监听 expandRequestCount：每次递增都触发展开（无论当前是否已展开）
    useEffect(() {
      if (expandCount.value > 0) {
        controller.expand(_initialSize.clamp(_minSize, _maxSize));
      }
      return null;
    }, [expandCount.value]);

    // 监听 collapseRequestCount：快捷键/命令请求折叠时执行折叠
    final collapseCount = useExistingSignal(
      XtermStore.instance.collapseRequestCount,
    );
    useEffect(() {
      if (collapseCount.value > 0) {
        controller.collapse();
      }
      return null;
    }, [collapseCount.value]);

    // 面板展开状态同步到 store：用户拖拽也会更新，供 togglePanel 判断方向
    useEffect(() {
      void sync() => XtermStore.instance.panelExpanded.value =
          !controller.isCollapsed.value;
      sync();
      controller.isCollapsed.addListener(sync);
      return () => controller.isCollapsed.removeListener(sync);
    }, []);

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

/// 可编程展开/折叠的侧边栏容器 — 监听 [SidebarStore] 切换计数，
/// 由命令面板/快捷键 Ctrl+B / Ctrl+U 控制，用户拖拽仍可正常折叠。
class _ControlledSidebar extends HookWidget {
  const _ControlledSidebar({
    required this.direction,
    required this.toggleCount,
    required this.expanded,
    required this.other,
    required this.child,
  });

  final ResizeDirection direction;
  final Signal<int> toggleCount;
  final Signal<bool> expanded;
  final Widget other;
  final Widget child;

  static const double _initialSize = 256;
  static const double _minSize = 180;
  static const double _maxSize = 400;

  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(
      () => ResizeBoxController(
        initialCollapsed: false,
        initialSize: _initialSize,
      ),
    );

    // 监听切换计数：按当前展开状态执行展开/折叠
    final count = useExistingSignal(toggleCount);
    useEffect(() {
      if (count.value > 0) {
        if (expanded.value) {
          controller.collapse();
        } else {
          controller.expand(_initialSize.clamp(_minSize, _maxSize));
        }
      }
      return null;
    }, [count.value]);

    // 展开状态同步到 store：用户拖拽也会更新，保证下次切换方向准确
    useEffect(() {
      void sync() => expanded.value = !controller.isCollapsed.value;
      sync();
      controller.isCollapsed.addListener(sync);
      return () => controller.isCollapsed.removeListener(sync);
    }, []);

    return ResizeBox(
      controller: controller,
      direction: direction,
      minSize: _minSize,
      initialSize: _initialSize,
      maxSize: _maxSize,
      collapseThreshold: 80,
      initialCollapsed: false,
      other: other,
      child: child,
    );
  }
}

/// Chat page layout.
///
/// Left panel | Chat + Terminal | Right panel (性能检测面板)。
/// 右面板在 `flutter run`（debug/release 均显示），打包后隐藏。
///
/// 移动端：单栏，仅渲染 ChatContent（无左栏 / 终端 / 右栏；
/// 终端面板不可用，`XtermStore` 的展开请求自然无人消费）。
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (isMobilePlatform) {
      // 检查点视图切换与桌面保持一致
      return SignalBuilder(
        builder: (_) =>
            CheckpointStore.instance.showCheckpointView.value
                ? const CheckpointList()
                : const ChatContent(),
      );
    }
    if (!_isRunningFromSource()) {
      // 打包后的 app，不显示性能面板
      return _buildTwoPanelLayout();
    }
    return _buildThreePanelLayout();
  }

  Widget _buildThreePanelLayout() {
    return _ControlledSidebar(
      direction: ResizeDirection.left,
      toggleCount: SidebarStore.instance.rightToggleCount,
      expanded: SidebarStore.instance.rightExpanded,
      other: _ControlledSidebar(
        direction: ResizeDirection.right,
        toggleCount: SidebarStore.instance.leftToggleCount,
        expanded: SidebarStore.instance.leftExpanded,
        other: _ExpandableTerminalPanel(
          other: SignalBuilder(
            builder: (_) => CheckpointStore.instance.showCheckpointView.value
                ? const CheckpointList()
                : const ChatContent(),
          ),
          child: TerminalPanel(),
        ),
        child: const LeftPanel(),
      ),
      child: const RightPanel(),
    );
  }

  Widget _buildTwoPanelLayout() {
    return _ControlledSidebar(
      direction: ResizeDirection.right,
      toggleCount: SidebarStore.instance.leftToggleCount,
      expanded: SidebarStore.instance.leftExpanded,
      other: _ExpandableTerminalPanel(
        other: SignalBuilder(
          builder: (_) => CheckpointStore.instance.showCheckpointView.value
              ? const CheckpointList()
              : const ChatContent(),
        ),
        child: const TerminalPanel(),
      ),
      child: const LeftPanel(),
    );
  }
}
