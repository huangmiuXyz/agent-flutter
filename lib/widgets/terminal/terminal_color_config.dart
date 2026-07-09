import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kterm/kterm.dart' as kterm;

import 'package:agent/theme/provider.dart';

part 'terminal_color_config.freezed.dart';

/// A configurable set of terminal ANSI colors.
///
/// Contains all 16 ANSI colors plus their bright variants, foreground,
/// background, cursor, selection, and search highlight colors.
///
/// Use [TerminalColorConfig.light] and [TerminalColorConfig.dark] for the
/// built-in defaults, or construct a custom instance for full control.
@freezed
sealed class TerminalColorConfig with _$TerminalColorConfig {
  const factory TerminalColorConfig({
    required Color cursor,
    required Color selection,
    required Color foreground,
    required Color background,
    required Color black,
    required Color red,
    required Color green,
    required Color yellow,
    required Color blue,
    required Color magenta,
    required Color cyan,
    required Color white,
    required Color brightBlack,
    required Color brightRed,
    required Color brightGreen,
    required Color brightYellow,
    required Color brightBlue,
    required Color brightMagenta,
    required Color brightCyan,
    required Color brightWhite,
    required Color searchHitBackground,
    required Color searchHitBackgroundCurrent,
    required Color searchHitForeground,
  }) = _TerminalColorConfig;

  /// Light theme terminal color palette.
  static const TerminalColorConfig light = TerminalColorConfig(
    cursor: Color(0xFF333333),
    selection: Color(0x40000000),
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
    searchHitBackground: Color(0xFFFFF2B0),
    searchHitBackgroundCurrent: Color(0xFF31FF26),
    searchHitForeground: Color(0xFF000000),
  );

  /// Dark theme terminal color palette.
  static const TerminalColorConfig dark = TerminalColorConfig(
    cursor: Color(0xFFF5F5F7),
    selection: Color(0x40FFFFFF),
    foreground: Color(0xFFF5F5F7),
    background: Color(0xFF181818),
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
    searchHitBackground: Color(0xFF2B2B2B),
    searchHitBackgroundCurrent: Color(0xFF31FF26),
    searchHitForeground: Color(0xFF000000),
  );
}

/// Extension methods on [TerminalColorConfig].
extension TerminalColorConfigX on TerminalColorConfig {
  /// Convert to [kterm.TerminalTheme] consumable by [TerminalView].
  ///
  /// Optionally overrides foreground/background from a [ColorScheme]
  /// to keep the terminal in sync with the app theme surface colors.
  kterm.TerminalTheme toTerminalTheme({ColorScheme? colorScheme}) {
    return kterm.TerminalTheme(
      cursor: cursor,
      selection: selection,
      foreground: colorScheme?.onSurface ?? foreground,
      background: colorScheme?.surface ?? background,
      black: black,
      red: red,
      green: green,
      yellow: yellow,
      blue: blue,
      magenta: magenta,
      cyan: cyan,
      white: white,
      brightBlack: brightBlack,
      brightRed: brightRed,
      brightGreen: brightGreen,
      brightYellow: brightYellow,
      brightBlue: brightBlue,
      brightMagenta: brightMagenta,
      brightCyan: brightCyan,
      brightWhite: brightWhite,
      searchHitBackground: searchHitBackground,
      searchHitBackgroundCurrent: searchHitBackgroundCurrent,
      searchHitForeground: searchHitForeground,
    );
  }
}

/// Provides a [kterm.TerminalTheme] that adapts to the current app theme (light/dark).
///
/// Uses [TerminalColorConfig.light] / [TerminalColorConfig.dark] as the base
/// palette, then overrides foreground/background from the active [ColorScheme]
/// so the terminal surface matches the rest of the app.
final terminalThemeProvider = Provider<kterm.TerminalTheme>((ref) {
  final config = ref.watch(themeProvider);
  final brightness = config.resolveBrightness();

  final base = brightness == Brightness.dark
      ? TerminalColorConfig.dark
      : TerminalColorConfig.light;

  final scheme = brightness == Brightness.dark
      ? config.darkColorScheme
      : config.lightColorScheme;

  return base.toTerminalTheme(colorScheme: scheme);
});
