import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kterm/kterm.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/terminal/provider.dart';
import 'package:agent/widgets/terminal/terminal_color_config.dart';

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

    useEffect(() {
      ref.read(terminalManagerProvider(id).notifier).startPty(shell: shell);
      return () => focusNode.value.dispose();
    }, []);

    useEffect(() {
      if (visible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            FocusScope.of(context).requestFocus(focusNode.value);
          } catch (_) {}
        });
      }
      return null;
    }, [visible, id]);

    return ClipRect(
      child: TerminalView(
        terminal,
        theme: theme,
        textStyle: TerminalStyle(
          fontFamily: custom.fontFamily,
          fontSize: custom.fontSizeBody,
          height: 1.2,
          fontFamilyFallback: const [
            'Menlo',
            'Consolas',
            'Courier New',
            'monospace',
          ],
        ),
        focusNode: focusNode.value,
        autofocus: false,
      ),
    );
  }
}
