import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kterm/kterm.dart';

import 'provider.dart';
import 'terminal_color_config.dart';

class TerminalWidget extends ConsumerWidget {
  const TerminalWidget({super.key, required this.config});

  final TerminalConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminal = ref.watch(terminalManagerProvider(config));
    final theme = ref.watch(terminalThemeProvider);

    return ClipRect(
      child: TerminalView(
        terminal,
        theme: theme,
        autofocus: true,
      ),
    );
  }
}
