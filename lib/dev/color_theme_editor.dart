import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/theme/provider.dart';
import 'package:agent/widgets/text/app_text.dart';

const List<Color> colorOptions = [
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

/// A right-tray editor for customizing theme colors at runtime.
class ColorThemeEditor extends ConsumerWidget {
  const ColorThemeEditor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(themeProvider);
    final isDark = config.resolveBrightness() == Brightness.dark;
    final effective = config.effectiveFor(isDark ? Brightness.dark : Brightness.light);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _colorGroup(context, 'Primary', [
          ('primary', '主题', effective.primary),
          ('onPrimary', '主题文', effective.onPrimary),
          ('primaryContainer', '主题容器', effective.primaryContainer),
          ('onPrimaryContainer', '容器文', effective.onPrimaryContainer),
        ], ref, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Secondary', [
          ('secondary', '次要', effective.secondary),
          ('onSecondary', '次要文', effective.onSecondary),
          ('secondaryContainer', '次要容器', effective.secondaryContainer),
          ('onSecondaryContainer', '容器文', effective.onSecondaryContainer),
        ], ref, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Tertiary', [
          ('tertiary', '第三', effective.tertiary),
          ('onTertiary', '第三文', effective.onTertiary),
          ('tertiaryContainer', '第三容器', effective.tertiaryContainer),
          ('onTertiaryContainer', '容器文', effective.onTertiaryContainer),
        ], ref, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Error', [
          ('error', '错误', effective.error),
          ('onError', '错误文', effective.onError),
          ('errorContainer', '错误容器', effective.errorContainer),
          ('onErrorContainer', '容器文', effective.onErrorContainer),
        ], ref, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Surface', [
          ('surface', '表面', effective.surface),
          ('onSurface', '表面文', effective.onSurface),
          ('onSurfaceVariant', '表面变文', effective.onSurfaceVariant),
          ('surfaceContainerLow', '容器低', effective.surfaceContainerLow),
          ('surfaceContainer', '容器', effective.surfaceContainer),
          ('surfaceContainerHigh', '容器高', effective.surfaceContainerHigh),
          ('surfaceContainerHighest', '容器最高', effective.surfaceContainerHighest),
        ], ref, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Outline', [
          ('outline', '轮廓', effective.outline),
          ('outlineVariant', '轮廓变', effective.outlineVariant),
        ], ref, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Inverse', [
          ('inverseSurface', '反表面', effective.inverseSurface),
          ('onInverseSurface', '反表面文', effective.onInverseSurface),
          ('inversePrimary', '反主题', effective.inversePrimary),
        ], ref, isDark, effective),
        const SizedBox(height: 8),
        _colorGroup(context, 'Other', [
          ('shadow', '阴影', effective.shadow),
          ('scrim', '遮罩', effective.scrim),
        ], ref, isDark, effective),
        const SizedBox(height: 16),
        AppText('图标粗细: ${config.iconThickness}',
            style: TextStyle(fontSize: 11, color: effective.onSurfaceVariant)),
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
        const SizedBox(height: 16),
        AppText('字体粗细: w${100 * (effective.fontWeight.index + 1)}',
            style: TextStyle(fontSize: 11, color: effective.onSurfaceVariant)),
        const SizedBox(height: 4),
        Slider(
          value: effective.fontWeight.index.toDouble(),
          min: 0,
          max: 8,
          divisions: 8,
          label: 'w${100 * (effective.fontWeight.index + 1)}',
          onChanged: (v) => ref.read(themeProvider.notifier).setFontWeight(
            FontWeight.values[v.round()],
          ),
        ),
        if (config.lightCustomTheme != null || config.darkCustomTheme != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => ref.read(themeProvider.notifier).resetCustomTheme(),
              child: AppText('恢复默认',
                  style: TextStyle(fontSize: 12, color: effective.primary)),
            ),
          ),
      ],
    );
  }

  Widget _colorGroup(BuildContext context, String label, List<(String field, String displayName, Color current)> fields, WidgetRef ref, bool isDark, CustomTheme effective) {
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
          children: colorOptions.map((c) => GestureDetector(
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
