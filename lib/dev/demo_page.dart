import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/theme/provider.dart';
import 'package:agent/widgets/button/app_button.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/list/app_list.dart';
import 'package:agent/dev/performance_monitor.dart';
import 'package:agent/dev/button_demo.dart';
import 'package:agent/dev/field_demo.dart';
import 'package:agent/dev/execute_panel.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/terminal/terminal_tabs.dart';
import 'package:agent/dev/color_theme_editor.dart';
import 'package:agent/dev/context_menu_demo.dart';
import 'package:agent/dev/fps_monitor.dart';
import 'package:agent/dev/grouped_list_demo.dart';

import 'package:agent/dev/resizebox_demo.dart';
import 'package:agent/dev/markdown_demo.dart';
import 'package:agent/widgets/resizebox/resizebox.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';

class DemoPage extends HookConsumerWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = useState(0);
    final config = ref.watch(themeProvider);
    final custom = CustomTheme.of(context);
    final showEditor = useState(false);
    final trayWidth = MediaQuery.of(context).size.width / 4;
    return Stack(
      children: [
        Positioned.fill(
          child: ResizeBox(
            other: ColoredBox(
              color: custom.colors.background,
              child: IndexedStack(
                index: selectedIndex.value,
                children: [
                  const ButtonDemo(),
                  Column(
                    children: [
                      Expanded(
                        child: TerminalTabs(active: selectedIndex.value == 1),
                      ),
                      SizedBox(height: 200, child: ExecutePanel()),
                    ],
                  ),
                  const PerformanceMonitor(),
                  const ContextMenuDemo(),
                  const GroupedListDemo(),
                  const FieldDemo(),
                  const ResizeBoxDemo(),
                  const ContentFrame(child: MarkdownDemo()),
                ],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: custom.colors.panel,
                border: Border(
                  right: BorderSide(color: custom.colors.selected),
                ),
              ),
              child: Column(
                children: [
                  AppList(
                    width: double.infinity,
                    children: [
                      AppListItem(
                        icon: 'square',
                        label: 'Button',
                        active: selectedIndex.value == 0,
                        onTap: () => selectedIndex.value = 0,
                      ),
                      AppListItem(
                        icon: 'terminal',
                        label: 'Terminal',
                        active: selectedIndex.value == 1,
                        onTap: () => selectedIndex.value = 1,
                      ),
                      AppListItem(
                        icon: 'activity',
                        label: 'Performance',
                        active: selectedIndex.value == 2,
                        onTap: () => selectedIndex.value = 2,
                      ),
                      AppListItem(
                        icon: 'terminalSquare',
                        label: 'Context Menu',
                        active: selectedIndex.value == 3,
                        onTap: () => selectedIndex.value = 3,
                      ),
                      AppListItem(
                        icon: 'layers',
                        label: 'List',
                        active: selectedIndex.value == 4,
                        onTap: () => selectedIndex.value = 4,
                      ),
                      AppListItem(
                        icon: 'move',
                        label: 'ResizeBox',
                        active: selectedIndex.value == 6,
                        onTap: () => selectedIndex.value = 6,
                      ),
                      AppListItem(
                        icon: 'fileCode',
                        label: 'Markdown',
                        active: selectedIndex.value == 7,
                        onTap: () => selectedIndex.value = 7,
                      ),
                      _SidebarInlineField(selectedIndex: selectedIndex),
                    ],
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        AppButton(
                          icon: switch (config.themeMode) {
                            ThemeMode.system => 'sun',
                            ThemeMode.light => 'sun',
                            ThemeMode.dark => 'moon',
                          },
                          variant: ButtonVariant.iconOnly,
                          text: switch (config.themeMode) {
                            ThemeMode.system => '主题: 系统',
                            ThemeMode.light => '主题: 亮色',
                            ThemeMode.dark => '主题: 暗色',
                          },
                          onPressed: () {
                            final next = switch (config.themeMode) {
                              ThemeMode.system => ThemeMode.light,
                              ThemeMode.light => ThemeMode.dark,
                              ThemeMode.dark => ThemeMode.system,
                            };
                            ref.read(themeProvider.notifier).setThemeMode(next);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const FpsMonitor(),

        // FAB
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            mini: true,
            onPressed: () => showEditor.value = !showEditor.value,
            backgroundColor: custom.colors.accent,
            foregroundColor: custom.colors.onAccent,
            child: AppIcon(
              'palette',
              size: custom.typography.subtitleSize,
              color: custom.colors.onAccent,
            ),
          ),
        ),
        // Backdrop
        if (showEditor.value)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => showEditor.value = false,
              child: Container(color: Colors.black26),
            ),
          ),
        // Right tray
        if (showEditor.value)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: trayWidth.clamp(200, 400),
            child: Material(
              elevation: 16,
              color: custom.colors.background,
              child: SafeArea(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        IconButton(
                          icon: AppIcon(
                            'x',
                            size: custom.typography.titleSize,
                            color: custom.colors.textSecondary,
                          ),
                          onPressed: () => showEditor.value = false,
                        ),
                      ],
                    ),
                    Expanded(child: ColorThemeEditor()),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SidebarInlineField extends HookWidget {
  final ValueNotifier<int> selectedIndex;

  const _SidebarInlineField({required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final isHovered = useState(false);
    final isPressed = useState(false);
    final controller = useTextEditingController(text: 'Field');
    final active = selectedIndex.value == 5;

    final bgColor = switch ((active, isPressed.value, isHovered.value)) {
      (true, _, _) => custom.colors.selected,
      (_, true, _) => custom.colors.selected,
      (_, _, true) => custom.colors.hover,
      _ => Colors.transparent,
    };
    final foreground = custom.colors.textPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => isHovered.value = true,
      onExit: (_) => isHovered.value = false,
      child: Material(
        color: bgColor,
        borderRadius: custom.radii.sm,
        child: InkWell(
          onTap: () => selectedIndex.value = 5,
          onHighlightChanged: (v) => isPressed.value = v,
          borderRadius: custom.radii.sm,
          splashFactory: NoSplash.splashFactory,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: SizedBox(
            height: custom.controls.mediumHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  AppIcon(
                    'pencil',
                    size: custom.typography.bodySize,
                    color: foreground,
                  ),
                  SizedBox(width: custom.spacing.sm),
                  Expanded(
                    child: AppField(
                      variant: FieldVariant.inline,
                      controller: controller,
                      size: FieldSize.md,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
