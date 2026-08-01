import 'package:flutter/material.dart';

enum AppColorRole {
  background,
  panel,
  panelElevated,
  hover,
  selected,
  textPrimary,
  textSecondary,
  textDisabled,
  accent,
  onAccent,
  accentHover,
  danger,
  onDanger,
  border,
  borderSubtle,
  separator,
  overlay,
  shadow,
  menuBackground,
  menuBorder,
  menuHover,
  cardBackground,
  cardBorder,
  success,
  warning,
  bottomPanel,
  resizeHandle,
}

@immutable
class AppColors {
  final Map<AppColorRole, Color> _colors;

  const AppColors._(Map<AppColorRole, Color> colors) : _colors = colors;

  factory AppColors._fromMap(Map<AppColorRole, Color> colors) =>
      AppColors._(Map.unmodifiable(colors));

  Color get background => _colors[AppColorRole.background]!;
  Color get panel => _colors[AppColorRole.panel]!;
  Color get panelElevated => _colors[AppColorRole.panelElevated]!;
  Color get hover => _colors[AppColorRole.hover]!;
  Color get selected => _colors[AppColorRole.selected]!;
  Color get textPrimary => _colors[AppColorRole.textPrimary]!;
  Color get textSecondary => _colors[AppColorRole.textSecondary]!;
  Color get textDisabled => _colors[AppColorRole.textDisabled]!;
  Color get accent => _colors[AppColorRole.accent]!;
  Color get onAccent => _colors[AppColorRole.onAccent]!;
  Color get accentHover => _colors[AppColorRole.accentHover]!;
  Color get danger => _colors[AppColorRole.danger]!;
  Color get onDanger => _colors[AppColorRole.onDanger]!;
  Color get border => _colors[AppColorRole.border]!;
  Color get borderSubtle => _colors[AppColorRole.borderSubtle]!;
  Color get separator => _colors[AppColorRole.separator]!;
  Color get overlay => _colors[AppColorRole.overlay]!;
  Color get shadow => _colors[AppColorRole.shadow]!;
  Color get menuBackground => _colors[AppColorRole.menuBackground]!;
  Color get menuBorder => _colors[AppColorRole.menuBorder]!;
  Color get menuHover => _colors[AppColorRole.menuHover]!;
  Color get cardBackground => _colors[AppColorRole.cardBackground]!;
  Color get cardBorder => _colors[AppColorRole.cardBorder]!;
  Color get success => _colors[AppColorRole.success]!;
  Color get warning => _colors[AppColorRole.warning]!;
  Color get bottomPanel => _colors[AppColorRole.bottomPanel]!;
  Color get resizeHandle => _colors[AppColorRole.resizeHandle]!;

  static final light = AppColors._fromMap({
    AppColorRole.background: const Color(0xFFF9F9F9),
    AppColorRole.panel: const Color(0xFFFDFDFD),
    AppColorRole.panelElevated: const Color(0xFFEBEBEB),
    AppColorRole.hover: const Color(0xFFE0E0E0),
    AppColorRole.selected: const Color(0xFFE8E8E8),
    AppColorRole.textPrimary: const Color(0xFF000000),
    AppColorRole.textSecondary: const Color(0xFF68686D),
    AppColorRole.textDisabled: const Color(0xFF9A9A9F),
    AppColorRole.accent: const Color(0xFF000000),
    AppColorRole.onAccent: const Color(0xFFFFFFFF),
    AppColorRole.accentHover: const Color(0xFF333333),
    AppColorRole.danger: const Color(0xFFFF3B30),
    AppColorRole.onDanger: const Color(0xFFFFFFFF),
    AppColorRole.border: const Color(0xFFD4D4D4),
    AppColorRole.borderSubtle: const Color(0xFFE6E6E6),
    AppColorRole.separator: const Color(0xFFD8D8D8),
    AppColorRole.overlay: const Color(0x66000000),
    AppColorRole.shadow: const Color(0xFF000000),
    AppColorRole.menuBackground: const Color(0xFFEBEBEC),
    AppColorRole.menuBorder: const Color(0xFFC9C9CA),
    AppColorRole.menuHover: const Color(0xFFDFDFE0),
    AppColorRole.cardBackground: const Color(0xFFFFFFFF),
    AppColorRole.cardBorder: const Color(0xFFE6E6E6),
    AppColorRole.success: const Color(0xFF198844),
    AppColorRole.warning: const Color(0xFFC47F00),
    AppColorRole.bottomPanel: const Color(0xFFF9F9F9), // 与 background 一致，终端面板与终端内容无缝衔接
    // VS Code sash 悬停色
    AppColorRole.resizeHandle: const Color(0xFF0078D4),
  });

  static final dark = AppColors._fromMap({
    AppColorRole.background: const Color(0xFF131313),
    AppColorRole.panel: const Color(0xFF2D2D2D),
    AppColorRole.panelElevated: const Color(0xFF262626),
    AppColorRole.hover: const Color(0xFF333333),
    AppColorRole.selected: const Color(0xFF404040),
    AppColorRole.textPrimary: const Color(0xFFF5F5F7),
    AppColorRole.textSecondary: const Color(0xFFA1A1A6),
    AppColorRole.textDisabled: const Color(0xFF69696E),
    AppColorRole.accent: const Color(0xFFFFFFFF),
    AppColorRole.onAccent: const Color(0xFF000000),
    AppColorRole.accentHover: const Color(0xFFE0E0E0),
    AppColorRole.danger: const Color(0xFFFF453A),
    AppColorRole.onDanger: const Color(0xFFFFFFFF),
    AppColorRole.border: const Color(0xFF404040),
    AppColorRole.borderSubtle: const Color(0xFF49454F),
    AppColorRole.separator: const Color(0xFF484848),
    AppColorRole.overlay: const Color(0x99000000),
    AppColorRole.shadow: const Color(0xFF000000),
    AppColorRole.menuBackground: const Color(0xFF2D2D2D),
    AppColorRole.menuBorder: const Color(0xFF404040),
    AppColorRole.menuHover: const Color(0xFF333333),
    AppColorRole.cardBackground: const Color(0xFF363636),
    AppColorRole.cardBorder: const Color(0xFF49454F),
    AppColorRole.success: const Color(0xFF4ADE80),
    AppColorRole.warning: const Color(0xFFFBBF24),
    AppColorRole.bottomPanel: const Color(0xFF131313),
    // VS Code sash 悬停色
    AppColorRole.resizeHandle: const Color(0xFF3794FF),
  });

  Color colorFor(AppColorRole role) => _colors[role]!;

  AppColors withColor(AppColorRole role, Color color) =>
      AppColors._fromMap({..._colors, role: color});

  AppColors apply(Map<AppColorRole, int> overrides) {
    if (overrides.isEmpty) return this;
    final updated = Map<AppColorRole, Color>.of(_colors);
    for (final entry in overrides.entries) {
      updated[entry.key] = Color(entry.value);
    }
    return AppColors._fromMap(updated);
  }

  static AppColors lerp(AppColors a, AppColors b, double t) {
    final merged = <AppColorRole, Color>{};
    for (final role in AppColorRole.values) {
      merged[role] = Color.lerp(a._colors[role]!, b._colors[role]!, t)!;
    }
    return AppColors._fromMap(merged);
  }
}
