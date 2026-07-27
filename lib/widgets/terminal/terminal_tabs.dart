import 'package:nanoid/nanoid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/shell_utils.dart';
import 'package:agent/store/xterm_store.dart';
import 'package:agent/widgets/terminal/xterm_widget.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

class TerminalTabs extends HookWidget {
  const TerminalTabs({super.key, this.active = true});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final tabsList = useExistingSignal(XtermStore.instance.tabs);
    final activeId = useExistingSignal(XtermStore.instance.activeTabId);
    final custom = CustomTheme.of(context);

    // 首次挂载时如果没有 tab，创建一个默认 tab。
    // 必须延迟到 post-frame，避免在 build 期间修改 signal 触发循环重建。
    // 用 addTab 而非 openTab —— 启动时不应自动展开面板。
    useEffect(() {
      if (XtermStore.instance.tabs.value.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (XtermStore.instance.tabs.value.isEmpty) {
            XtermStore.instance.addTab(nanoid(8), shell: resolveShell());
          }
        });
      }
      return null;
    }, []);

    // 计算激活索引
    final tabs = tabsList.value;
    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }
    int activeIndex = tabs.indexWhere((t) => t.id == activeId.value);
    if (activeIndex < 0) activeIndex = 0;

    final tabBarHeight = custom.controls.mediumHeight;

    return Stack(
      children: [
        Column(
          children: [
            Container(
              height: tabBarHeight - 1.0,
              color: custom.colors.panelElevated,
            ),
            Container(height: 1.0, color: custom.colors.selected),
            SizedBox(height: custom.spacing.xs),
            Expanded(
              child: IndexedStack(
                index: activeIndex,
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    XtermTerminalWidget(
                      key: ValueKey(tabs[i].id),
                      id: tabs[i].id,
                      shell: tabs[i].shell,
                      visible: active && activeIndex == i,
                    ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: tabBarHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Minimum width for the empty area right of tabs (double-tap to add)
              final rightMinWidth = custom.controls.tabAddButtonWidth;
              final leftMaxWidth = constraints.maxWidth - rightMinWidth;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    flex: 0,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: leftMaxWidth),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < tabs.length; i++)
                              _TabItem(
                                label: shellLabel(tabs[i].shell),
                                active: activeIndex == i,
                                isFirst: i == 0,
                                onTap: () =>
                                    XtermStore.instance.setActiveTab(tabs[i].id),
                                onClose: tabs.length > 1
                                    ? () =>
                                        XtermStore.instance.closeTab(tabs[i].id)
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onDoubleTap: () => XtermStore.instance
                          .addTab(nanoid(8), shell: resolveShell()),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool active;
  final bool isFirst;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _TabItem({
    required this.label,
    required this.active,
    required this.isFirst,
    required this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: custom.controls.mediumHeight,
        padding: EdgeInsets.symmetric(horizontal: custom.spacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? custom.colors.background : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: active && !isFirst
                  ? custom.colors.selected
                  : Colors.transparent,
              width: 1.0,
            ),
            right: BorderSide(
              color: active ? custom.colors.selected : Colors.transparent,
              width: 1.0,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppIcon(
              'terminalSquare',
              size: custom.typography.captionSize,
              color: active
                  ? custom.colors.textPrimary
                  : custom.colors.textSecondary,
            ),
            SizedBox(width: custom.spacing.xs),
            AppText(
              label,
              variant: AppTextVariant.caption,
              color: active
                  ? custom.colors.textPrimary
                  : custom.colors.textSecondary,
            ),
            if (onClose != null) ...[
              SizedBox(width: custom.spacing.xs),
              AppIconButton(
                icon: 'x',
                size: ButtonSize.sm,
                tooltip: '关闭',
                hoverStyle: false,
                onPressed: onClose,
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(
                    EdgeInsets.all(custom.spacing.xs),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
