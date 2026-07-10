import 'dart:io';

import 'package:nanoid/nanoid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/terminal/terminal_widget.dart';
import 'package:agent/widgets/button/app_button.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

String tabLabel(String shell) {
  final resolved = shell.isNotEmpty ? shell : resolveShell();
  return resolved.split(RegExp(r'[\\/]')).last;
}

String resolveShell() {
  if (Platform.isWindows) return 'cmd.exe';
  final envShell = Platform.environment['SHELL'];
  if (envShell != null && envShell.isNotEmpty) return envShell;
  return File('/bin/zsh').existsSync() ? '/bin/zsh' : '/bin/bash';
}

class TerminalTabs extends HookWidget {
  const TerminalTabs({super.key, this.active = true});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final tabs = useState<List<_TabState>>([_TabState(id: nanoid(8))]);
    final activeIndex = useState(0);
    final custom = CustomTheme.of(context);

    void addTab(String shell) {
      tabs.value = [...tabs.value, _TabState(id: nanoid(8), shell: shell)];
      activeIndex.value = tabs.value.length - 1;
    }

    void closeTab(int index) {
      if (tabs.value.length <= 1) return;
      final newTabs = [...tabs.value]..removeAt(index);
      tabs.value = newTabs;
      if (activeIndex.value >= newTabs.length) {
        activeIndex.value = newTabs.length - 1;
      } else if (activeIndex.value > index) {
        activeIndex.value = activeIndex.value - 1;
      }
    }

    final tabBarHeight = custom.controlHeightMd;

    return Stack(
      children: [
        Column(
          children: [
            Container(
              height: tabBarHeight - 1.0,
              color: custom.surfaceContainer,
            ),
            Container(height: 1.0, color: custom.surfaceContainerHighest),
            SizedBox(height: custom.spacingXs),
            Expanded(
              child: IndexedStack(
                index: activeIndex.value,
                children: [
                  for (var i = 0; i < tabs.value.length; i++)
                    TerminalWidget(
                      key: ValueKey(tabs.value[i].id),
                      id: tabs.value[i].id,
                      shell: tabs.value[i].shell,
                      visible: active && activeIndex.value == i,
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
              const double rightMinWidth = 30.0;
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
                            for (var i = 0; i < tabs.value.length; i++)
                              _TabItem(
                                label: tabLabel(tabs.value[i].shell),
                                active: activeIndex.value == i,
                                isFirst: i == 0,
                                onTap: () => activeIndex.value = i,
                                onClose: tabs.value.length > 1
                                    ? () => closeTab(i)
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onDoubleTap: () => addTab(resolveShell()),
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

class _TabState {
  final String id;
  final String shell;
  const _TabState({required this.id, this.shell = ''});
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
        height: custom.controlHeightMd,
        padding: EdgeInsets.symmetric(horizontal: custom.spacingSm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? custom.surface : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: active && !isFirst
                  ? custom.surfaceContainerHighest
                  : Colors.transparent,
              width: 1.0,
            ),
            right: BorderSide(
              color: active
                  ? custom.surfaceContainerHighest
                  : Colors.transparent,
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
              size: custom.fontSizeCaption,
              color: active ? custom.onSurface : custom.onSurfaceVariant,
            ),
            SizedBox(width: custom.spacingXs),
            AppText(
              label,
              variant: AppTextVariant.caption,
              color: active ? custom.onSurface : custom.onSurfaceVariant,
            ),
            if (onClose != null) ...[
              SizedBox(width: custom.spacingXs),
              AppButton(
                icon: 'x',
                variant: ButtonVariant.iconOnly,
                size: ButtonSize.sm,
                text: '关闭',
                hoverStyle: false,
                onPressed: onClose,
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.all(2)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
