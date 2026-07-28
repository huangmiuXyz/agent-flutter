/// 显示设置页 — 主题模式与字体大小。
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/store/theme_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/reactive/reactive.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Font size scale presets with display labels.
const _fontSizePresets = [
  ('较小', 0.875),
  ('默认', 1.0),
  ('较大', 1.125),
  ('最大', 1.25),
];

/// 显示设置页。
class DisplaySettingsPage extends HookWidget {
  const DisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final store = ThemeStore.instance;

    // 响应式订阅信号
    final settings = useExistingSignal(store.settings);
    final currentMode = settings.value.themeMode;
    final currentScale = settings.value.fontSizeScale;

    return ContentFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: custom.spacing.pageTop - 70),

          FormRow(
            label: '主题模式',
            child: _ThemeModeSelector(
              current: currentMode,
              onChanged: (mode) => store.setThemeMode(mode),
            ),
          ),

          SizedBox(height: custom.spacing.sm),
          const Divider(height: 1),
          SizedBox(height: custom.spacing.sm),

          FormRow(
            label: '字体大小',
            child: _FontSizeSelector(
              current: currentScale,
              onChanged: (scale) => store.setFontSizeScale(scale),
            ),
          ),
        ],
      ),
    );
  }
}

/// Theme mode selector — three tappable segments: 浅色 / 深色 / 跟随系统.
class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeModeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    const options = [
      (ThemeMode.light, '浅色'),
      (ThemeMode.dark, '深色'),
      (ThemeMode.system, '跟随系统'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: custom.colors.panel,
        borderRadius: custom.radii.sm,
        border: Border.all(color: custom.colors.borderSubtle),
      ),
      padding: EdgeInsets.all(custom.spacing.xs),
      child: Row(
        children: [
          for (final (i, (mode, label)) in options.indexed) ...[
            if (i > 0) SizedBox(width: custom.spacing.xs),
            Expanded(
              child: _SegmentButton(
                label: label,
                selected: current == mode,
                onTap: () => onChanged(mode),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single segment in the theme mode selector.
class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: custom.spacing.sm),
        decoration: BoxDecoration(
          color: selected ? custom.colors.accent : Colors.transparent,
          borderRadius: custom.radii.xs,
        ),
        child: Center(
          child: AppText(
            label,
            variant: AppTextVariant.body,
            color: selected
                ? custom.colors.onAccent
                : custom.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Font size selector — slider with preset labels underneath.
class _FontSizeSelector extends StatelessWidget {
  final double current;
  final ValueChanged<double> onChanged;

  const _FontSizeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    // Map current scale to slider position (0.0 ~ 3.0)
    final presetValues = _fontSizePresets.map((e) => e.$2).toList();
    final currentIndex = presetValues.indexOf(current);
    final sliderValue = currentIndex >= 0
        ? currentIndex.toDouble()
        : 1.0; // default to "默认"

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview text showing current size
        Padding(
          padding: EdgeInsets.only(bottom: custom.spacing.sm),
          child: AppText(
            '预览文字（${_labelForScale(current)}）',
            variant: AppTextVariant.body,
            style: TextStyle(fontSize: 14 * current),
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: custom.colors.accent,
            inactiveTrackColor: custom.colors.borderSubtle,
            thumbColor: custom.colors.accent,
            overlayColor: custom.colors.accent.withValues(alpha: 0.12),
            valueIndicatorColor: custom.colors.menuBackground,
            valueIndicatorTextStyle: custom.typography.styleForSize(
              custom.typography.captionSize,
              custom.colors.textPrimary,
            ),
          ),
          child: Slider(
            value: sliderValue,
            min: 0,
            max: (_fontSizePresets.length - 1).toDouble(),
            divisions: _fontSizePresets.length - 1,
            label: _labelForScale(current),
            onChanged: (v) => onChanged(presetValues[v.round()]),
          ),
        ),
        // Preset labels
        Padding(
          padding: EdgeInsets.symmetric(horizontal: custom.spacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (label, _) in _fontSizePresets)
                AppText(
                  label,
                  variant: AppTextVariant.caption,
                  color: custom.colors.textSecondary,
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _labelForScale(double scale) {
    for (final (label, s) in _fontSizePresets) {
      if (s == scale) return label;
    }
    return '默认';
  }
}
