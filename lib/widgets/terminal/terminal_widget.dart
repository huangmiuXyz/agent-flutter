import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kterm/kterm.dart';

import 'package:agent/theme/custom_theme.dart';
import 'provider.dart';
import 'terminal_color_config.dart';

class TerminalWidget extends HookConsumerWidget {
  const TerminalWidget({
    super.key,
    required this.id,
    this.shell = '',
    this.visible = true,
  });

  final String id;
  final String shell;
  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminal = ref.watch(terminalManagerProvider(id));
    final theme = ref.watch(terminalThemeProvider);
    final custom = CustomTheme.of(context);
    final focusNode = useRef(FocusNode());

    // Start PTY once on mount.
    useEffect(() {
      ref.read(terminalManagerProvider(id).notifier).startPty(shell: shell);
      return () => focusNode.value.dispose();
    }, []);

    // Pause/resume PTY reading and request focus when visible.
    useEffect(() {
      final manager = ref.read(terminalManagerProvider(id).notifier);
      if (visible) {
        manager.resume();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(focusNode.value);
        });
      } else {
        manager.suspend();
      }
      return null;
    }, [visible, id]);

    return ClipRect(
      child: TerminalView(
        terminal,
        theme: theme,
        textStyle: TerminalStyle(
          fontFamily: custom.fontFamily,
          fontSize: custom.fontSizeSubtitle,
        ),
        focusNode: focusNode.value,
        autofocus: false,
      ),
    );
  }
}
