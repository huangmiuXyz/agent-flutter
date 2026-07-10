import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flterm/flterm.dart';

import 'package:agent/theme/provider.dart';

const darkAnsi = [
  Color(0xFF1D1F21),
  Color(0xFFCC342B),
  Color(0xFF198844),
  Color(0xFFFBA922),
  Color(0xFF3971ED),
  Color(0xFFA36AC7),
  Color(0xFF3971ED),
  Color(0xFFC5C8C6),
  Color(0xFF969896),
  Color(0xFFCC342B),
  Color(0xFF198844),
  Color(0xFFFBA922),
  Color(0xFF3971ED),
  Color(0xFFA36AC7),
  Color(0xFF3971ED),
  Color(0xFFFFFFFF),
];

const lightAnsi = [
  Color(0xFF2E3436),
  Color(0xFFCC0000),
  Color(0xFF4E9A06),
  Color(0xFFC4A000),
  Color(0xFF3465A4),
  Color(0xFF75507B),
  Color(0xFF06989A),
  Color(0xFFD3D7CF),
  Color(0xFF555753),
  Color(0xFFEF2929),
  Color(0xFF8AE234),
  Color(0xFFFCE94F),
  Color(0xFF729FCF),
  Color(0xFFAD7FA8),
  Color(0xFF34E2E2),
  Color(0xFFEEEEEC),
];

final fltermPaletteProvider = Provider<ColorPalette>((ref) {
  final config = ref.watch(themeProvider);
  final brightness = config.resolveBrightness();
  final effective = config.effectiveFor(brightness);
  final isDark = brightness == Brightness.dark;
  return ColorPalette(
    ansiColors: isDark ? darkAnsi : lightAnsi,
    background: effective.surface,
    foreground: effective.onSurface,
  );
});
