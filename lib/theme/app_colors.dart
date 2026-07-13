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
}

@immutable
class AppColors {
  const AppColors({
    required this.background,
    required this.panel,
    required this.panelElevated,
    required this.hover,
    required this.selected,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.accent,
    required this.onAccent,
    required this.accentHover,
    required this.danger,
    required this.onDanger,
    required this.border,
    required this.borderSubtle,
    required this.separator,
    required this.overlay,
    required this.shadow,
    required this.menuBackground,
    required this.menuBorder,
    required this.menuHover,
    required this.cardBackground,
    required this.cardBorder,
    required this.success,
    required this.warning,
  });

  final Color background;
  final Color panel;
  final Color panelElevated;
  final Color hover;
  final Color selected;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color accent;
  final Color onAccent;
  final Color accentHover;
  final Color danger;
  final Color onDanger;
  final Color border;
  final Color borderSubtle;
  final Color separator;
  final Color overlay;
  final Color shadow;
  final Color menuBackground;
  final Color menuBorder;
  final Color menuHover;
  final Color cardBackground;
  final Color cardBorder;
  final Color success;
  final Color warning;

  static const light = AppColors(
    background: Color(0xFFF9F9F9),
    panel: Color(0xFFFDFDFD),
    panelElevated: Color(0xFFEBEBEB),
    hover: Color(0xFFE0E0E0),
    selected: Color(0xFFD4D4D4),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF68686D),
    textDisabled: Color(0xFF9A9A9F),
    accent: Color(0xFF000000),
    onAccent: Color(0xFFFFFFFF),
    accentHover: Color(0xFF333333),
    danger: Color(0xFFFF3B30),
    onDanger: Color(0xFFFFFFFF),
    border: Color(0xFFD4D4D4),
    borderSubtle: Color(0xFFE6E6E6),
    separator: Color(0xFFD8D8D8),
    overlay: Color(0x66000000),
    shadow: Color(0xFF000000),
    menuBackground: Color(0xFFEBEBEC),
    menuBorder: Color(0xFFC9C9CA),
    menuHover: Color(0xFFDFDFE0),
    cardBackground: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE6E6E6),
    success: Color(0xFF198844),
    warning: Color(0xFFC47F00),
  );

  static const dark = AppColors(
    background: Color(0xFF131313),
    panel: Color(0xFF2D2D2D),
    panelElevated: Color(0xFF262626),
    hover: Color(0xFF333333),
    selected: Color(0xFF404040),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFFA1A1A6),
    textDisabled: Color(0xFF69696E),
    accent: Color(0xFFFFFFFF),
    onAccent: Color(0xFF000000),
    accentHover: Color(0xFFE0E0E0),
    danger: Color(0xFFFF453A),
    onDanger: Color(0xFFFFFFFF),
    border: Color(0xFF404040),
    borderSubtle: Color(0xFF49454F),
    separator: Color(0xFF484848),
    overlay: Color(0x99000000),
    shadow: Color(0xFF000000),
    menuBackground: Color(0xFF2D2D2D),
    menuBorder: Color(0xFF404040),
    menuHover: Color(0xFF333333),
    cardBackground: Color(0xFF363636),
    cardBorder: Color(0xFF49454F),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
  );

  Color colorFor(AppColorRole role) => switch (role) {
    AppColorRole.background => background,
    AppColorRole.panel => panel,
    AppColorRole.panelElevated => panelElevated,
    AppColorRole.hover => hover,
    AppColorRole.selected => selected,
    AppColorRole.textPrimary => textPrimary,
    AppColorRole.textSecondary => textSecondary,
    AppColorRole.textDisabled => textDisabled,
    AppColorRole.accent => accent,
    AppColorRole.onAccent => onAccent,
    AppColorRole.accentHover => accentHover,
    AppColorRole.danger => danger,
    AppColorRole.onDanger => onDanger,
    AppColorRole.border => border,
    AppColorRole.borderSubtle => borderSubtle,
    AppColorRole.separator => separator,
    AppColorRole.overlay => overlay,
    AppColorRole.shadow => shadow,
    AppColorRole.menuBackground => menuBackground,
    AppColorRole.menuBorder => menuBorder,
    AppColorRole.menuHover => menuHover,
    AppColorRole.cardBackground => cardBackground,
    AppColorRole.cardBorder => cardBorder,
    AppColorRole.success => success,
    AppColorRole.warning => warning,
  };

  AppColors withColor(AppColorRole role, Color color) => AppColors(
    background: role == AppColorRole.background ? color : background,
    panel: role == AppColorRole.panel ? color : panel,
    panelElevated: role == AppColorRole.panelElevated ? color : panelElevated,
    hover: role == AppColorRole.hover ? color : hover,
    selected: role == AppColorRole.selected ? color : selected,
    textPrimary: role == AppColorRole.textPrimary ? color : textPrimary,
    textSecondary: role == AppColorRole.textSecondary ? color : textSecondary,
    textDisabled: role == AppColorRole.textDisabled ? color : textDisabled,
    accent: role == AppColorRole.accent ? color : accent,
    onAccent: role == AppColorRole.onAccent ? color : onAccent,
    accentHover: role == AppColorRole.accentHover ? color : accentHover,
    danger: role == AppColorRole.danger ? color : danger,
    onDanger: role == AppColorRole.onDanger ? color : onDanger,
    border: role == AppColorRole.border ? color : border,
    borderSubtle: role == AppColorRole.borderSubtle ? color : borderSubtle,
    separator: role == AppColorRole.separator ? color : separator,
    overlay: role == AppColorRole.overlay ? color : overlay,
    shadow: role == AppColorRole.shadow ? color : shadow,
    menuBackground: role == AppColorRole.menuBackground
        ? color
        : menuBackground,
    menuBorder: role == AppColorRole.menuBorder ? color : menuBorder,
    menuHover: role == AppColorRole.menuHover ? color : menuHover,
    cardBackground: role == AppColorRole.cardBackground
        ? color
        : cardBackground,
    cardBorder: role == AppColorRole.cardBorder ? color : cardBorder,
    success: role == AppColorRole.success ? color : success,
    warning: role == AppColorRole.warning ? color : warning,
  );

  AppColors apply(Map<AppColorRole, int> overrides) {
    var result = this;
    for (final entry in overrides.entries) {
      result = result.withColor(entry.key, Color(entry.value));
    }
    return result;
  }

  static AppColors lerp(AppColors a, AppColors b, double t) => AppColors(
    background: Color.lerp(a.background, b.background, t)!,
    panel: Color.lerp(a.panel, b.panel, t)!,
    panelElevated: Color.lerp(a.panelElevated, b.panelElevated, t)!,
    hover: Color.lerp(a.hover, b.hover, t)!,
    selected: Color.lerp(a.selected, b.selected, t)!,
    textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
    textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
    textDisabled: Color.lerp(a.textDisabled, b.textDisabled, t)!,
    accent: Color.lerp(a.accent, b.accent, t)!,
    onAccent: Color.lerp(a.onAccent, b.onAccent, t)!,
    accentHover: Color.lerp(a.accentHover, b.accentHover, t)!,
    danger: Color.lerp(a.danger, b.danger, t)!,
    onDanger: Color.lerp(a.onDanger, b.onDanger, t)!,
    border: Color.lerp(a.border, b.border, t)!,
    borderSubtle: Color.lerp(a.borderSubtle, b.borderSubtle, t)!,
    separator: Color.lerp(a.separator, b.separator, t)!,
    overlay: Color.lerp(a.overlay, b.overlay, t)!,
    shadow: Color.lerp(a.shadow, b.shadow, t)!,
    menuBackground: Color.lerp(a.menuBackground, b.menuBackground, t)!,
    menuBorder: Color.lerp(a.menuBorder, b.menuBorder, t)!,
    menuHover: Color.lerp(a.menuHover, b.menuHover, t)!,
    cardBackground: Color.lerp(a.cardBackground, b.cardBackground, t)!,
    cardBorder: Color.lerp(a.cardBorder, b.cardBorder, t)!,
    success: Color.lerp(a.success, b.success, t)!,
    warning: Color.lerp(a.warning, b.warning, t)!,
  );
}
