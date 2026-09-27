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
    AppColorRole.background: const Color(0xFFF8F9FA),
    AppColorRole.panel: const Color(0xFFFFFFFF),
    AppColorRole.panelElevated: const Color(0xFFF1F3F5),
    AppColorRole.hover: const Color(0xFFE9ECEF),
    AppColorRole.selected: const Color(0xFFE2E6EA),
    AppColorRole.textPrimary: const Color(0xFF1A1D20),
    AppColorRole.textSecondary: const Color(0xFF6C757D),
    AppColorRole.textDisabled: const Color(0xFFADB5BD),
    AppColorRole.accent: const Color(0xFF0F172A),
    AppColorRole.onAccent: const Color(0xFFFFFFFF),
    AppColorRole.accentHover: const Color(0xFF1E293B),
    AppColorRole.danger: const Color(0xFFEF4444),
    AppColorRole.onDanger: const Color(0xFFFFFFFF),
    AppColorRole.border: const Color(0xFFE2E8F0),
    AppColorRole.borderSubtle: const Color(0xFFEDF2F7),
    AppColorRole.separator: const Color(0xFFE2E8F0),
    AppColorRole.overlay: const Color(0x52000000),
    AppColorRole.shadow: const Color(0x0F000000),
    AppColorRole.menuBackground: const Color(0xFFFFFFFF),
    AppColorRole.menuBorder: const Color(0xFFE2E8F0),
    AppColorRole.menuHover: const Color(0xFFF1F5F9),
    AppColorRole.cardBackground: const Color(0xFFFFFFFF),
    AppColorRole.cardBorder: const Color(0xFFE2E8F0),
    AppColorRole.success: const Color(0xFF10B981),
    AppColorRole.warning: const Color(0xFFF59E0B),
    AppColorRole.bottomPanel: const Color(0xFFF8F9FA), // 与 background 一致，终端面板与终端内容无缝衔接
    // VS Code sash 悬停色
    AppColorRole.resizeHandle: const Color(0xFF3B82F6),
  });

  static final dark = AppColors._fromMap({
    AppColorRole.background: const Color(0xFF0F1115),
    AppColorRole.panel: const Color(0xFF16181D),
    AppColorRole.panelElevated: const Color(0xFF1E2228),
    AppColorRole.hover: const Color(0xFF262A32),
    AppColorRole.selected: const Color(0xFF2C323C),
    AppColorRole.textPrimary: const Color(0xFFF1F5F9),
    AppColorRole.textSecondary: const Color(0xFF94A3B8),
    AppColorRole.textDisabled: const Color(0xFF64748B),
    AppColorRole.accent: const Color(0xFFF8FAFC),
    AppColorRole.onAccent: const Color(0xFF0F172A),
    AppColorRole.accentHover: const Color(0xFFE2E8F0),
    AppColorRole.danger: const Color(0xFFF87171),
    AppColorRole.onDanger: const Color(0xFFFFFFFF),
    AppColorRole.border: const Color(0xFF262A33),
    AppColorRole.borderSubtle: const Color(0xFF1E222A),
    AppColorRole.separator: const Color(0xFF262A33),
    AppColorRole.overlay: const Color(0x99000000),
    AppColorRole.shadow: const Color(0x40000000),
    AppColorRole.menuBackground: const Color(0xFF1A1D24),
    AppColorRole.menuBorder: const Color(0xFF2E3440),
    AppColorRole.menuHover: const Color(0xFF262C36),
    AppColorRole.cardBackground: const Color(0xFF181B20),
    AppColorRole.cardBorder: const Color(0xFF282D37),
    AppColorRole.success: const Color(0xFF34D399),
    AppColorRole.warning: const Color(0xFFFBBF24),
    AppColorRole.bottomPanel: const Color(0xFF0F1115),
    // VS Code sash 悬停色
    AppColorRole.resizeHandle: const Color(0xFF38BDF8),
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
