import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:xterm2/xterm.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/terminal/xterm_provider.dart';
import 'package:agent/widgets/terminal/terminal_palette.dart';

class XtermTerminalWidget extends HookConsumerWidget {
  const XtermTerminalWidget({
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
    final session = ref.watch(xtermManagerProvider(id));
    final custom = CustomTheme.of(context);
    final focusNode = useRef(FocusNode());

    useEffect(() {
      ref.read(xtermManagerProvider(id).notifier).startPty(shell: shell);
      return () {};
    }, []);

    useEffect(() {
      if (visible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            FocusScope.of(context).requestFocus(focusNode.value);
          }
        });
      }
      return null;
    }, [visible, id]);

    final theme = ref.watch(xtermThemeProvider);
    final textStyle = TerminalStyle(
      fontSize: custom.fontSizeBody,
      fontFamily: fontWeightToFamily(custom.fontWeight) ?? 'JetBrainsMono',
    );

    return ClipRect(
      child: TerminalView(
        session.terminal,
        controller: session.controller,
        focusNode: focusNode.value,
        autofocus: visible,
        theme: theme,
        textStyle: textStyle,
      ),
    );
  }
}
