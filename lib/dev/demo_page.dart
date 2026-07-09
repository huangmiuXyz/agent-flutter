import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/theme/provider.dart';
import 'package:agent/widgets/button/app_button.dart';
import 'package:agent/widgets/terminal/provider.dart';
import 'package:agent/widgets/terminal/terminal_widget.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/list/app_list.dart';
import 'package:agent/widgets/text/app_text.dart';

const List<Color> _colorOptions = [
  Color(0xFF000000),
  Color(0xFF616161),
  Color(0xFF9E9E9E),
  Color(0xFF795548),
  Color(0xFFE53935),
  Color(0xFFFF6F00),
  Color(0xFFFDD835),
  Color(0xFF43A047),
  Color(0xFF00ACC1),
  Color(0xFF1E88E5),
  Color(0xFF3949AB),
  Color(0xFF8E24AA),
  Color(0xFFD81B60),
  Color(0xFFF48FB1),
  Color(0xFFFFFFFF),
];

class DemoPage extends HookConsumerWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = useState(0);
    final config = ref.watch(themeProvider);
    final custom = CustomTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 256,
          child: Container(
            decoration: BoxDecoration(
              color: custom.surfaceContainerLow,
              border: Border(
                right: BorderSide(
                  color: custom.surfaceContainerHighest,
                ),
              ),
            ),
            child: Column(
            children: [
              AppList(
                width: double.infinity,
                children: [
                  AppListItem(
                    icon: 'rectangleVertical',
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
      Expanded(
          child: ColoredBox(
            color: custom.surface,
            child: IndexedStack(
            index: selectedIndex.value,
            children: [
              _ButtonDemo(),
              _TerminalTabs(),
              ],
            ),
          ),
        ),
      ],
    );
    }
}

String _tabLabel(TerminalConfig config) {
  final shell = config.shell.isNotEmpty ? config.shell : config.resolvedShell;
  return shell.split(RegExp(r'[\\/]')).last;
}

List<String> _availableShells() {
  if (kIsWeb) return ['/bin/bash'];
  if (!Platform.isWindows) return ['/bin/bash', '/bin/zsh', '/bin/sh'];
  final shells = <String>['cmd.exe'];
  if (Process.runSync('where', ['pwsh.exe']).exitCode == 0) {
    shells.add('pwsh.exe');
  }
  if (File(r'C:\Program Files\Git\bin\bash.exe').existsSync()) {
    shells.add(r'C:\Program Files\Git\bin\bash.exe');
  }
  if (Process.runSync('where', ['wsl']).exitCode == 0) {
    shells.add('wsl.exe');
  }
  return shells;
}

class _TerminalTabs extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = useState<List<TerminalConfig>>([const TerminalConfig(id: 'tab-0')]);
    final active = useState(0);
    final custom = CustomTheme.of(context);

    void addTab(String shell) {
      final id = 'tab-${tabs.value.length}';
      tabs.value = [...tabs.value, TerminalConfig(id: id, shell: shell)];
      active.value = tabs.value.length - 1;
    }

    void closeTab(int index) {
      if (tabs.value.length <= 1) return;
      final newTabs = [...tabs.value]..removeAt(index);
      tabs.value = newTabs;
      if (active.value >= newTabs.length) {
        active.value = newTabs.length - 1;
      } else if (active.value > index) {
        active.value = active.value - 1;
      }
    }

    return Column(
      children: [
        Container(
          height: 36,
          color: custom.surfaceContainerLow,
          child: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: tabs.value.length,
                  itemBuilder: (context, index) => _TabItem(
                    label: _tabLabel(tabs.value[index]),
                    active: active.value == index,
                    onTap: () => active.value = index,
                    onClose: tabs.value.length > 1
                        ? () => closeTab(index)
                        : null,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.add, size: 16, color: custom.onSurface),
                tooltip: 'New terminal',
                onSelected: addTab,
                itemBuilder: (context) => [
                  for (final shell in _availableShells())
                    PopupMenuItem(value: shell, child: Text(shell, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: CustomTheme.of(context).spacingXs),
        Expanded(
          child: IndexedStack(
            index: active.value,
            children: [
              for (final c in tabs.value)
                TerminalWidget(key: ValueKey(c.id), config: c),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _TabItem({
    required this.label,
    required this.active,
    required this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? custom.surface : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: active ? custom.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? custom.onSurface : custom.onSurfaceVariant,
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close, size: 14, color: custom.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ButtonDemo extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(themeProvider);
    final isDark = config.resolveBrightness() == Brightness.dark;
    final effective = config.effectiveFor(isDark ? Brightness.dark : Brightness.light);

    final colors = [
      ('primary', '主题', effective.primary),
      ('onPrimary', '主题文', effective.onPrimary),
      ('primaryContainer', '主题容器', effective.primaryContainer),
      ('onPrimaryContainer', '容器文', effective.onPrimaryContainer),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppText('配色 (${isDark ? "暗色" : "亮色"}模式)',
            style: TextStyle(fontSize: 12, color: effective.onSurfaceVariant)),
        const SizedBox(height: 8),
        _colorGroup(context, 'Primary', colors, ref, config, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Secondary', [
          ('secondary', '次要', effective.secondary),
          ('onSecondary', '次要文', effective.onSecondary),
          ('secondaryContainer', '次要容器', effective.secondaryContainer),
          ('onSecondaryContainer', '容器文', effective.onSecondaryContainer),
        ], ref, config, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Tertiary', [
          ('tertiary', '第三', effective.tertiary),
          ('onTertiary', '第三文', effective.onTertiary),
          ('tertiaryContainer', '第三容器', effective.tertiaryContainer),
          ('onTertiaryContainer', '容器文', effective.onTertiaryContainer),
        ], ref, config, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Error', [
          ('error', '错误', effective.error),
          ('onError', '错误文', effective.onError),
          ('errorContainer', '错误容器', effective.errorContainer),
          ('onErrorContainer', '容器文', effective.onErrorContainer),
        ], ref, config, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Surface', [
          ('surface', '表面', effective.surface),
          ('onSurface', '表面文', effective.onSurface),
          ('onSurfaceVariant', '表面变文', effective.onSurfaceVariant),
        ], ref, config, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Surface Container', [
          ('surfaceContainerLow', '容器低', effective.surfaceContainerLow),
          ('surfaceContainer', '容器', effective.surfaceContainer),
          ('surfaceContainerHigh', '容器高', effective.surfaceContainerHigh),
          ('surfaceContainerHighest', '容器最高', effective.surfaceContainerHighest),
        ], ref, config, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Outline', [
          ('outline', '轮廓', effective.outline),
          ('outlineVariant', '轮廓变', effective.outlineVariant),
        ], ref, config, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Inverse', [
          ('inverseSurface', '反表面', effective.inverseSurface),
          ('onInverseSurface', '反表面文', effective.onInverseSurface),
          ('inversePrimary', '反主题', effective.inversePrimary),
        ], ref, config, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Other', [
          ('shadow', '阴影', effective.shadow),
          ('scrim', '遮罩', effective.scrim),
        ], ref, config, isDark, effective),
        if (config.lightCustomTheme != null || config.darkCustomTheme != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => ref.read(themeProvider.notifier).resetCustomTheme(),
              child: AppText('恢复默认',
                  style: TextStyle(fontSize: 12, color: effective.primary)),
            ),
          ),
        const SizedBox(height: 16),

        AppText('图标粗细: ${config.iconThickness}', style: TextStyle(fontSize: 12, color: effective.onSurfaceVariant)),
        const SizedBox(height: 4),
        Slider(
          value: config.iconThickness.toDouble(),
          min: 0,
          max: 600,
          divisions: 6,
          label: '${config.iconThickness}',
          onChanged: (v) =>
              ref.read(themeProvider.notifier).setIconThickness(v.round()),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: ['sun', 'moon', 'brush', 'settings', 'refresh', 'trash']
              .map((n) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        AppIcon(n, size: 24),
                        const SizedBox(height: 4),
                        AppText(n, style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 24),
        AppText('按钮', style: TextStyle(fontSize: 12, color: effective.onSurfaceVariant)),
        const SizedBox(height: 8),
        AppButton(variant: ButtonVariant.primary, onPressed: () {}, text: '主要'),
        const SizedBox(height: 8),
        Row(
          children: [
            AppButton(variant: ButtonVariant.primary, onPressed: () {}, text: '小', size: ButtonSize.sm),
            const SizedBox(width: 8),
            AppButton(variant: ButtonVariant.primary, onPressed: () {}, text: '中'),
            const SizedBox(width: 8),
            AppButton(variant: ButtonVariant.primary, onPressed: () {}, text: '大', size: ButtonSize.lg),
          ],
        ),
        const SizedBox(height: 8),
        AppButton(variant: ButtonVariant.secondary, onPressed: () {}, text: '次要'),
        const SizedBox(height: 8),
        AppButton(variant: ButtonVariant.text, onPressed: () {}, text: '文字'),
        const SizedBox(height: 8),
        Row(
          children: [
            AppButton(variant: ButtonVariant.iconOnly, icon: 'settings', onPressed: () {}),
            const SizedBox(width: 8),
            AppButton(variant: ButtonVariant.iconOnly, icon: 'refresh', onPressed: () {}),
            const SizedBox(width: 8),
            AppButton(variant: ButtonVariant.iconOnly, icon: 'trash', onPressed: () {}),
          ],
        ),
      ],
    );
  }

  Widget _colorGroup(BuildContext context, String label, List<(String field, String displayName, Color current)> fields, WidgetRef ref, ThemeConfig config, bool isDark, CustomTheme effective) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: effective.onSurfaceVariant)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: fields.map((f) =>
            _colorField(context, f.$2, f.$1, f.$3, ref, isDark, effective),
          ).toList(),
        ),
      ],
    );
  }

  Widget _colorField(BuildContext context, String label, String field, Color current, WidgetRef ref, bool isDark, CustomTheme effective) {
    return GestureDetector(
      onTap: () => _showColorPicker(context, current, effective, (c) {
        if (isDark) {
          ref.read(themeProvider.notifier).setDarkColor(field, c);
        } else {
          ref.read(themeProvider.notifier).setLightColor(field, c);
        }
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: current,
              shape: BoxShape.circle,
              border: Border.all(color: effective.outline),
            ),
          ),
          const SizedBox(height: 2),
          AppText(label, style: const TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, Color current, CustomTheme effective, void Function(Color) onSelected) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('选择颜色'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _colorOptions.map((c) => GestureDetector(
            onTap: () {
              onSelected(c);
              Navigator.pop(ctx);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: c == current ? effective.primary : effective.outline,
                  width: c == current ? 3 : 1,
                ),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }
}
