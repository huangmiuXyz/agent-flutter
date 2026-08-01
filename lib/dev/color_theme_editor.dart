import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/store/theme_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/button/app_text_button.dart';
import 'package:agent/widgets/text/app_text.dart';

const colorOptions = <Color>[
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

const _groups = <String, List<AppColorRole>>{
  '基础': [
    AppColorRole.background,
    AppColorRole.panel,
    AppColorRole.panelElevated,
    AppColorRole.hover,
    AppColorRole.selected,
  ],
  '文本': [
    AppColorRole.textPrimary,
    AppColorRole.textSecondary,
    AppColorRole.textDisabled,
  ],
  '强调与状态': [
    AppColorRole.accent,
    AppColorRole.onAccent,
    AppColorRole.accentHover,
    AppColorRole.danger,
    AppColorRole.onDanger,
    AppColorRole.success,
    AppColorRole.warning,
  ],
  '边框与浮层': [
    AppColorRole.border,
    AppColorRole.borderSubtle,
    AppColorRole.overlay,
    AppColorRole.shadow,
    AppColorRole.menuBackground,
    AppColorRole.menuBorder,
    AppColorRole.menuHover,
    AppColorRole.resizeHandle,
  ],
};

const _labels = <AppColorRole, String>{
  AppColorRole.background: '背景',
  AppColorRole.panel: '面板',
  AppColorRole.panelElevated: '浮起面板',
  AppColorRole.hover: '悬停',
  AppColorRole.selected: '选中',
  AppColorRole.textPrimary: '主文本',
  AppColorRole.textSecondary: '次文本',
  AppColorRole.textDisabled: '禁用文本',
  AppColorRole.accent: '强调',
  AppColorRole.onAccent: '强调文本',
  AppColorRole.accentHover: '强调悬停',
  AppColorRole.danger: '危险',
  AppColorRole.onDanger: '危险文本',
  AppColorRole.border: '边框',
  AppColorRole.borderSubtle: '弱边框',
  AppColorRole.overlay: '遮罩',
  AppColorRole.shadow: '阴影',
  AppColorRole.menuBackground: '菜单背景',
  AppColorRole.menuBorder: '菜单边框',
  AppColorRole.menuHover: '菜单悬停',
  AppColorRole.success: '成功',
  AppColorRole.warning: '警告',
  AppColorRole.resizeHandle: '拖拽手柄',
};

class ColorThemeEditor extends HookWidget {
  const ColorThemeEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = useExistingSignal(ThemeStore.instance.settings);
    final editingBrightness = useState(Brightness.light);
    final effective = ThemeStore.instance.effectiveFor(editingBrightness.value);
    final colors = effective.colors;

    return ListView(
      padding: EdgeInsets.all(effective.spacing.md),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildBrightnessButton(
                text: '亮色',
                isActive: editingBrightness.value == Brightness.light,
                onPressed: () => editingBrightness.value = Brightness.light,
              ),
            ),
            SizedBox(width: effective.spacing.sm),
            Expanded(
              child: _buildBrightnessButton(
                text: '暗色',
                isActive: editingBrightness.value == Brightness.dark,
                onPressed: () => editingBrightness.value = Brightness.dark,
              ),
            ),
          ],
        ),
        SizedBox(height: effective.spacing.md),
        for (final group in _groups.entries) ...[
          _colorGroup(context, group.key, group.value, effective),
          SizedBox(height: effective.spacing.sm),
        ],
        SizedBox(height: effective.spacing.md),
        AppText(
          '正文字重: w${settings.value.fontWeightValue}',
          variant: AppTextVariant.caption,
          color: colors.textSecondary,
        ),
        _themedSlider(
          effective,
          value: settings.value.fontWeightValue.toDouble(),
          min: 100,
          max: 900,
          divisions: 8,
          onChanged: (value) => ThemeStore.instance
              .setFontWeight(_fontWeight(value.round())),
        ),
        if (settings.value.hasColorOverrides) ...[
          SizedBox(height: effective.spacing.md),
          AppSecondaryButton(
            text: '重置当前配色',
            onPressed: () => ThemeStore.instance
                .resetColors(brightness: editingBrightness.value),
          ),
        ],
        SizedBox(height: effective.spacing.sm),
        AppTextButton(
          text: '恢复全部默认设置',
          onPressed: () => ThemeStore.instance.resetAll(),
        ),
      ],
    );
  }

  Widget _buildBrightnessButton({
    required String text,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    if (isActive) {
      return AppPrimaryButton(text: text, onPressed: onPressed);
    }
    return AppSecondaryButton(text: text, onPressed: onPressed);
  }

  Widget _colorGroup(
    BuildContext context,
    String label,
    List<AppColorRole> roles,
    CustomTheme theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          variant: AppTextVariant.caption,
          color: theme.colors.textSecondary,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: theme.spacing.xs),
        Wrap(
          spacing: theme.spacing.md,
          runSpacing: theme.spacing.sm,
          children: [
            for (final role in roles)
              _colorField(
                context,
                role,
                theme.colors.colorFor(role),
                theme,
              ),
          ],
        ),
      ],
    );
  }

  Widget _colorField(
    BuildContext context,
    AppColorRole role,
    Color current,
    CustomTheme theme,
  ) {
    return GestureDetector(
      onTap: () => _showColorPicker(context, current, theme, (color) {
        final brightness = theme.brightness;
        ThemeStore.instance.setColor(brightness, role, color);
      }),
      child: Semantics(
        button: true,
        label: '修改${_labels[role]}颜色',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: current,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colors.border),
              ),
            ),
            const SizedBox(height: 2),
            AppText(_labels[role]!, style: const TextStyle(fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _themedSlider(
    CustomTheme theme, {
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: theme.colors.accent,
        inactiveTrackColor: theme.colors.borderSubtle,
        thumbColor: theme.colors.accent,
        overlayColor: theme.colors.accent.withValues(alpha: 0.12),
        valueIndicatorColor: theme.colors.menuBackground,
        valueIndicatorTextStyle: theme.typography.styleForSize(
          theme.typography.captionSize,
          theme.colors.textPrimary,
        ),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: '${value.round()}',
        onChanged: onChanged,
      ),
    );
  }

  void _showColorPicker(
    BuildContext context,
    Color current,
    CustomTheme theme,
    ValueChanged<Color> onSelected,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: theme.colors.overlay,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 280,
          padding: EdgeInsets.all(theme.spacing.md),
          decoration: BoxDecoration(
            color: theme.colors.menuBackground,
            border: Border.all(color: theme.colors.menuBorder),
            borderRadius: theme.radii.md,
            boxShadow: theme.shadows.large,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText('选择颜色', variant: AppTextVariant.subtitle),
              SizedBox(height: theme.spacing.md),
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: [
                  for (final color in colorOptions)
                    GestureDetector(
                      onTap: () {
                        onSelected(color);
                        Navigator.pop(dialogContext);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color == current
                                ? theme.colors.accent
                                : theme.colors.border,
                            width: color == current ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  FontWeight _fontWeight(int value) => FontWeight.values.firstWhere(
    (weight) => weight.value == value,
    orElse: () => FontWeight.w400,
  );
}
