/// VS Code 风格图标 Tab 栏：一排线性图标按钮，激活项在按钮下方
/// 显示指示条（参考 VS Code 工具栏图标样式）。
library;

import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';

/// 一个图标式 Tab 栏（如左面板的「对话 / 检查点」切换）。
///
/// 与 [AppTabBar]（文字分段）互补：渲染一排图标按钮，内容切换
/// 仍由调用方通过 [activeIndex] / [onChanged] 控制。
class AppIconTabBar extends StatelessWidget {
  const AppIconTabBar({
    super.key,
    required this.icons,
    required this.tooltips,
    required this.activeIndex,
    required this.onChanged,
  }) : assert(icons.length == tooltips.length);

  /// 每个 tab 的图标（Lucide 线性图标，20x20）。
  final List<IconData> icons;

  /// 每个 tab 的悬停提示。
  final List<String> tooltips;

  /// 当前激活的 tab 下标。
  final int activeIndex;

  /// 点击 tab 时回调（传 tab 下标）。
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < icons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _IconTab(
            icon: icons[i],
            tooltip: tooltips[i],
            active: activeIndex == i,
            onTap: () => onChanged(i),
          ),
        ],
      ],
    );
  }
}

/// 单个图标 tab：悬停高亮背景 + 激活白色指示条。
class _IconTab extends StatefulWidget {
  const _IconTab({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_IconTab> createState() => _IconTabState();
}

class _IconTabState extends State<_IconTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    // 激活/悬停 = 高亮（textPrimary），否则次级色（VS Code 灰图标）
    final iconColor = widget.active || _hovered
        ? custom.colors.textPrimary
        : custom.colors.textSecondary;
    return Tooltip(
      message: widget.tooltip,
      decoration: BoxDecoration(
        color: custom.colors.menuBackground,
        border: Border.all(color: custom.colors.menuBorder),
        borderRadius: custom.radii.xs,
        boxShadow: custom.shadows.small,
      ),
      textStyle: custom.typography.styleForSize(
        custom.typography.captionSize,
        custom.colors.textPrimary,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Stack(
            // 指示条绘制在按钮下方，允许越界绘制
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _hovered ? custom.colors.hover : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(widget.icon, size: 20, color: iconColor),
              ),
              // 激活指示条：按钮下方 5px 间隙，宽 18 高 2 圆角条
              if (widget.active)
                Positioned(
                  bottom: -7,
                  child: Container(
                    width: 18,
                    height: 2,
                    decoration: BoxDecoration(
                      color: custom.colors.accent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
