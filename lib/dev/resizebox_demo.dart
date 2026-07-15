import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'package:agent/widgets/resizebox/resizebox.dart';

/// A demo page showcasing [ResizeBox] with a bottom panel layout.
///
/// The page is split into a main content area and a resizable bottom panel.
/// Uses [ResizeDirection.top] so that [child] is the bottom panel and
/// [other] fills the remaining space on top.
class ResizeBoxDemo extends HookWidget {
  const ResizeBoxDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final collapsedState = useState(false);
    final demoIndex = useState(0);

    final demos = <Widget>[
      _BottomPanelDemo(custom: custom, collapsedState: collapsedState),
      _BottomPanelWithInnerSplitDemo(
        custom: custom,
        collapsedState: collapsedState,
      ),
      _ThreePanelLayoutDemo(custom: custom, collapsedState: collapsedState),
      _VscodeLayoutDemo(custom: custom, collapsedState: collapsedState),
    ];

    final labels = [
      'Bottom Panel',
      'Bottom + Inner Split',
      'Three Panel',
      'ALL',
    ];

    return Column(
      children: [
        // tab bar
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: labels.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, i) {
              final active = demoIndex.value == i;
              return GestureDetector(
                onTap: () => demoIndex.value = i,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? custom.colors.accent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: active
                            ? custom.colors.accent
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: AppText(
                    labels[i],
                    variant: AppTextVariant.caption,
                    color: active
                        ? custom.colors.accent
                        : custom.colors.textSecondary,
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        // bottom panel status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: custom.colors.selected,
          child: Row(
            children: [
              AppText(
                '下面板状态: ${collapsedState.value ? "已隐藏" : "展开"}',
                variant: AppTextVariant.caption,
                color: custom.colors.textSecondary,
              ),
              if (collapsedState.value) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => collapsedState.value = false,
                  child: AppText(
                    '点击展开',
                    variant: AppTextVariant.caption,
                    color: custom.colors.accent,
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(child: demos[demoIndex.value]),
      ],
    );
  }
}

/// Simple bottom panel: main content on top, resizable panel at bottom.
///
/// Drag the bottom panel's top edge **down** to collapse/hide it.
/// When collapsed, hover or click the thin accent strip at the bottom to
/// re-expand.
class _BottomPanelDemo extends StatelessWidget {
  const _BottomPanelDemo({required this.custom, required this.collapsedState});
  final CustomTheme custom;
  final ValueNotifier<bool> collapsedState;

  @override
  Widget build(BuildContext context) {
    return ResizeBox(
      direction: ResizeDirection.top,
      minSize: 40,
      initialSize: 150,
      maxSize: 400,
      collapseThreshold: 60,
      onCollapseChanged: (v) => collapsedState.value = v,
      other: Container(
        color: custom.colors.background,
        child: _PanelLabel(
          label: '主内容区\n(ResizeBox other)',
          color: custom.colors.accent.withValues(alpha: 0.1),
        ),
      ),
      child: Container(
        color: custom.colors.panel,
        child: _PanelLabel(
          label: '下面板\n(ResizeBox child)\n\n拖拽顶部手柄往下\n即可隐藏面板',
          color: custom.colors.accent.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

/// Bottom panel with a horizontal split inside the bottom panel.
class _BottomPanelWithInnerSplitDemo extends StatelessWidget {
  const _BottomPanelWithInnerSplitDemo({
    required this.custom,
    required this.collapsedState,
  });
  final CustomTheme custom;
  final ValueNotifier<bool> collapsedState;

  @override
  Widget build(BuildContext context) {
    return ResizeBox(
      direction: ResizeDirection.top,
      minSize: 60,
      initialSize: 200,
      maxSize: 500,
      collapseThreshold: 60,
      onCollapseChanged: (v) => collapsedState.value = v,
      other: Container(
        color: custom.colors.background,
        child: _PanelLabel(
          label: '主内容区\n(ResizeBox other)',
          color: custom.colors.accent.withValues(alpha: 0.1),
        ),
      ),
      child: ResizeBox(
        direction: ResizeDirection.right,
        minSize: 60,
        initialSize: 150,
        maxSize: 500,
        other: Container(
          color: custom.colors.panel,
          child: _PanelLabel(
            label: '下面板 - 右侧\n(inner ResizeBox other)',
            color: custom.colors.accent.withValues(alpha: 0.2),
          ),
        ),
        child: Container(
          color: custom.colors.background,
          child: _PanelLabel(
            label: '下面板 - 左侧\n(inner ResizeBox child)',
            color: custom.colors.accent.withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }
}

/// Three-panel layout: left sidebar, main content, bottom panel.
class _ThreePanelLayoutDemo extends StatelessWidget {
  const _ThreePanelLayoutDemo({
    required this.custom,
    required this.collapsedState,
  });
  final CustomTheme custom;
  final ValueNotifier<bool> collapsedState;

  @override
  Widget build(BuildContext context) {
    return ResizeBox(
      direction: ResizeDirection.right,
      minSize: 120,
      initialSize: 180,
      maxSize: 350,
      other: ResizeBox(
        direction: ResizeDirection.top,
        minSize: 40,
        initialSize: 150,
        maxSize: 400,
        collapseThreshold: 60,
        onCollapseChanged: (v) => collapsedState.value = v,
        other: Container(
          color: custom.colors.background,
          child: _PanelLabel(
            label: '主内容区\n(level 2: other)',
            color: custom.colors.accent.withValues(alpha: 0.1),
          ),
        ),
        child: Container(
          color: custom.colors.panel,
          child: _PanelLabel(
            label: '下面板\n(level 2: child)',
            color: custom.colors.accent.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Container(
        color: custom.colors.panel,
        child: _PanelLabel(
          label: '左侧栏\n(level 1: child)',
          color: custom.colors.accent.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// VS Code-like layout: left sidebar + top panel + main content +
/// bottom panel + right sidebar.
///
/// Nesting (4 levels):
/// 1. [ResizeDirection.right]  → left sidebar | rest
/// 2. [ResizeDirection.left]   → [top+main+bottom] | right sidebar
/// 3. [ResizeDirection.bottom] → top panel | [main+bottom]
/// 4. [ResizeDirection.top]    → main content | bottom panel
class _VscodeLayoutDemo extends StatelessWidget {
  const _VscodeLayoutDemo({required this.custom, required this.collapsedState});
  final CustomTheme custom;
  final ValueNotifier<bool> collapsedState;

  @override
  Widget build(BuildContext context) {
    return ResizeBox(
      // Level 1: left sidebar | [top+main+bottom | right sidebar]
      direction: ResizeDirection.right,
      minSize: 120,
      initialSize: 180,
      maxSize: 300,
      other: ResizeBox(
        // Level 2: [top+main+bottom] | right sidebar
        direction: ResizeDirection.left,
        minSize: 80,
        initialSize: 160,
        maxSize: 300,
        other: ResizeBox(
          // Level 3: top panel | [main+bottom]
          direction: ResizeDirection.bottom,
          minSize: 40,
          initialSize: 100,
          maxSize: 250,
          other: ResizeBox(
            // Level 4: main content | bottom panel
            direction: ResizeDirection.top,
            minSize: 40,
            initialSize: 140,
            maxSize: 400,
            collapseThreshold: 60,
            onCollapseChanged: (v) => collapsedState.value = v,
            other: Container(
              color: custom.colors.background,
              child: _PanelLabel(
                label: '编辑器\n(主内容区)',
                color: custom.colors.accent.withValues(alpha: 0.1),
              ),
            ),
            child: Container(
              color: custom.colors.panel,
              child: _PanelLabel(
                label: '终端\n(下面板)\n\n拖拽顶部手柄往下隐藏',
                color: custom.colors.accent.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Container(
            color: custom.colors.panel,
            child: _PanelLabel(
              label: '上面板\n(搜索 / 调试)',
              color: custom.colors.accent.withValues(alpha: 0.15),
            ),
          ),
        ),
        child: Container(
          color: custom.colors.panel,
          child: _PanelLabel(
            label: '右侧栏\n(大纲)',
            color: custom.colors.accent.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Container(
        color: custom.colors.panel,
        child: _PanelLabel(
          label: '左侧栏\n(资源管理器)',
          color: custom.colors.accent.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _PanelLabel extends StatelessWidget {
  const _PanelLabel({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Container(
      decoration: BoxDecoration(color: color),
      alignment: Alignment.center,
      child: AppText(
        label,
        textAlign: TextAlign.center,
        variant: AppTextVariant.caption,
        color: custom.colors.textSecondary,
      ),
    );
  }
}
