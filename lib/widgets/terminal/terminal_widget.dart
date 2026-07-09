import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kterm/kterm.dart';

import 'provider.dart';
import 'terminal_color_config.dart';

class TerminalWidget extends ConsumerWidget {
  const TerminalWidget({
    super.key,
    required this.id,
    this.shell = '',
  });

  final String id;
  final String shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminal = ref.watch(terminalManagerProvider(id));
    final theme = ref.watch(terminalThemeProvider);

    // Start PTY once when the provider is first created
    ref.listen(terminalManagerProvider(id), (previous, next) {
      if (previous == null) {
        ref
            .read(terminalManagerProvider(id).notifier)
            .startPty(shell: shell);
      }
    });

    return ClipRect(
      child: TerminalView(
        terminal,
        theme: theme,
        autofocus: true,
      ),
    );
  }
}
