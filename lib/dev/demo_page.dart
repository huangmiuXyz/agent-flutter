import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/theme/provider.dart';
import 'package:agent/widgets/button/app_button.dart';
import 'package:agent/widgets/list/app_list.dart';
import 'package:agent/dev/performance_monitor.dart';
import 'package:agent/dev/button_demo.dart';
import 'package:agent/dev/execute_panel.dart';
import 'package:agent/widgets/terminal/terminal_tabs.dart';
import 'package:agent/dev/color_theme_editor.dart';
import 'package:agent/dev/context_menu_demo.dart';
import 'package:agent/dev/fps_monitor.dart';
import 'package:agent/dev/grouped_list_demo.dart';

import 'package:agent/dev/resizebox_demo.dart';
import 'package:agent/widgets/resizebox/resizebox.dart';

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
                  const ResizeBoxDemo(),
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
                        active: selectedIndex.value == 5,
                        onTap: () => selectedIndex.value = 5,
                      ),
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
            child: Icon(
              LucideIcons.palette,
              size: custom.typography.subtitleSize,
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
                          icon: Icon(
                            LucideIcons.x,
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
