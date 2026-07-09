import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kterm/kterm.dart';

import 'provider.dart';
import 'terminal_color_config.dart';

class TerminalWidget extends HookConsumerWidget {
  const TerminalWidget({super.key, required this.config});

  final TerminalConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminal = ref.watch(terminalManagerProvider(config));
    final theme = ref.watch(terminalThemeProvider);
    final controller = useMemoized(() => TerminalController());

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(terminalManagerProvider(config).notifier).startPty();
      });
      return null;
    }, [config]);

    return ClipRect(
      child: TerminalView(
        terminal,
        controller: controller,
        theme: theme,
        autofocus: true,
      ),
    );
  }
}
