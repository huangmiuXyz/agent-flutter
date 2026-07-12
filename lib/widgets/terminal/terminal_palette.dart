import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

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

final xtermThemeProvider = Provider<TerminalTheme>((ref) {
  final config = ref.watch(themeProvider);
  final brightness = config.resolveBrightness();
  final effective = config.effectiveFor(brightness);
  final isDark = brightness == Brightness.dark;
  final c = isDark ? darkAnsi : lightAnsi;
  return TerminalTheme(
    cursor: isDark ? const Color(0xFFC5C8C6) : const Color(0xFF2E3436),
    selection: isDark
        ? const Color(0x406DA9FF)
        : const Color(0x403465A4),
    foreground: effective.onSurface,
    background: effective.surface,
    black: c[0],
    red: c[1],
    green: c[2],
    yellow: c[3],
    blue: c[4],
    magenta: c[5],
    cyan: c[6],
    white: c[7],
    brightBlack: c[8],
    brightRed: c[9],
    brightGreen: c[10],
    brightYellow: c[11],
    brightBlue: c[12],
    brightMagenta: c[13],
    brightCyan: c[14],
    brightWhite: c[15],
    searchHitBackground: isDark
        ? const Color(0x80FBA922)
        : const Color(0x80C4A000),
    searchHitBackgroundCurrent: isDark
        ? const Color(0xCCFBA922)
        : const Color(0xCCC4A000),
    searchHitForeground: isDark
        ? const Color(0xFF1D1F21)
        : const Color(0xFFFFFFFF),
  );
});
