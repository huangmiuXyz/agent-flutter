import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xterm2/xterm.dart';

import 'package:agent/theme/provider.dart';

part 'terminal_palette.g.dart';

extension on TerminalTheme {
  TerminalTheme copyWith({
    Color? cursor,
    Color? selection,
    Color? foreground,
    Color? background,
    Color? black,
    Color? red,
    Color? green,
    Color? yellow,
    Color? blue,
    Color? magenta,
    Color? cyan,
    Color? white,
    Color? brightBlack,
    Color? brightRed,
    Color? brightGreen,
    Color? brightYellow,
    Color? brightBlue,
    Color? brightMagenta,
    Color? brightCyan,
    Color? brightWhite,
    Color? searchHitBackground,
    Color? searchHitBackgroundCurrent,
    Color? searchHitForeground,
  }) {
    return TerminalTheme(
      cursor: cursor ?? this.cursor,
      selection: selection ?? this.selection,
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
      black: black ?? this.black,
      red: red ?? this.red,
      green: green ?? this.green,
      yellow: yellow ?? this.yellow,
      blue: blue ?? this.blue,
      magenta: magenta ?? this.magenta,
      cyan: cyan ?? this.cyan,
      white: white ?? this.white,
      brightBlack: brightBlack ?? this.brightBlack,
      brightRed: brightRed ?? this.brightRed,
      brightGreen: brightGreen ?? this.brightGreen,
      brightYellow: brightYellow ?? this.brightYellow,
      brightBlue: brightBlue ?? this.brightBlue,
      brightMagenta: brightMagenta ?? this.brightMagenta,
      brightCyan: brightCyan ?? this.brightCyan,
      brightWhite: brightWhite ?? this.brightWhite,
      searchHitBackground: searchHitBackground ?? this.searchHitBackground,
      searchHitBackgroundCurrent:
          searchHitBackgroundCurrent ?? this.searchHitBackgroundCurrent,
      searchHitForeground: searchHitForeground ?? this.searchHitForeground,
    );
  }
}

final _darkTheme = TerminalTheme(
  cursor: Color(0xFFC5C8C6),
  selection: Color(0x406DA9FF),
  foreground: Color(0xFFF5F5F7),
  background: Color(0xFF131313),
  black: Color(0xFF1D1F21),
  red: Color(0xFFCC342B),
  green: Color(0xFF198844),
  yellow: Color(0xFFFBA922),
  blue: Color(0xFF3971ED),
  magenta: Color(0xFFA36AC7),
  cyan: Color(0xFF3971ED),
  white: Color(0xFFC5C8C6),
  brightBlack: Color(0xFF969896),
  brightRed: Color(0xFFCC342B),
  brightGreen: Color(0xFF198844),
  brightYellow: Color(0xFFFBA922),
  brightBlue: Color(0xFF3971ED),
  brightMagenta: Color(0xFFA36AC7),
  brightCyan: Color(0xFF3971ED),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0x80FBA922),
  searchHitBackgroundCurrent: Color(0xCCFBA922),
  searchHitForeground: Color(0xFF1D1F21),
);

final _lightTheme = TerminalTheme(
  cursor: Color(0xFF2E3436),
  selection: Color(0x403465A4),
  foreground: Color(0xFF000000),
  background: Color(0xFFF9F9F9),
  black: Color(0xFF2E3436),
  red: Color(0xFFCC0000),
  green: Color(0xFF4E9A06),
  yellow: Color(0xFFC4A000),
  blue: Color(0xFF3465A4),
  magenta: Color(0xFF75507B),
  cyan: Color(0xFF06989A),
  white: Color(0xFFD3D7CF),
  brightBlack: Color(0xFF555753),
  brightRed: Color(0xFFEF2929),
  brightGreen: Color(0xFF8AE234),
  brightYellow: Color(0xFFFCE94F),
  brightBlue: Color(0xFF729FCF),
  brightMagenta: Color(0xFFAD7FA8),
  brightCyan: Color(0xFF34E2E2),
  brightWhite: Color(0xFFEEEEEC),
  searchHitBackground: Color(0x80C4A000),
  searchHitBackgroundCurrent: Color(0xCCC4A000),
  searchHitForeground: Color(0xFFFFFFFF),
);

@riverpod
TerminalTheme xtermTheme(Ref ref) {
  final settings = ref.watch(themeProvider);
  final brightness = ref.watch(effectiveBrightnessProvider);
  final effective = settings.effectiveFor(brightness);
  return (brightness == Brightness.dark ? _darkTheme : _lightTheme).copyWith(
    foreground: effective.colors.textPrimary,
    background: effective.colors.background,
  );
}
