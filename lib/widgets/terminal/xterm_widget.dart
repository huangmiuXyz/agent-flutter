import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:xterm2/xterm.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/context_menu/context_menu.dart';
import 'package:agent/widgets/terminal/key_handler.dart';
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
      fontSize: custom.typography.bodySize,
      fontFamily: custom.typography.effectiveFontFamily ?? 'monospace',
    );

    // Single reusable handler instance (stateless).
    final deleteHandler = useMemoized(() => DeleteSelectionHandler());

    final terminalContent = ClipRect(
      child: TerminalView(
        session.terminal,
        controller: session.controller,
        focusNode: focusNode.value,
        autofocus: visible,
        theme: theme,
        textStyle: textStyle,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              deleteHandler.canHandle(event.logicalKey)) {
            if (deleteHandler.handle(session.terminal, session.controller)) {
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        onTapUp: (details, offset) {
          ref.read(xtermManagerProvider(id).notifier).handleTap(offset);
        },
      ),
    );

    return MenuArea(
      builder: (context) {
        final manager = ref.read(xtermManagerProvider(id).notifier);
        final hasSelection = session.controller.selection != null;
        return [
          MenuItem(
            label: '复制',
            icon: 'copy',
            shortcut: 'Ctrl+Shift+C',
            enabled: hasSelection,
            onTap: () => manager.copySelection(),
          ),
          MenuItem(
            label: '剪切',
            icon: 'scissors',
            shortcut: 'Ctrl+Shift+X',
            enabled: hasSelection,
            onTap: () => manager.cutSelection(),
          ),
          MenuItem(
            label: '粘贴',
            icon: 'clipboardPaste',
            shortcut: 'Ctrl+Shift+V',
            onTap: () => manager.pasteText(),
          ),
          MenuItem(
            label: '粘贴文字',
            icon: 'clipboardType',
            onTap: () => manager.pasteText(),
          ),
          MenuItem(
            label: '删除',
            icon: 'delete',
            enabled: hasSelection,
            onTap: () => manager.deleteSelection(),
          ),
          const MenuItem.separator(),
          MenuItem(
            label: '全选',
            icon: 'checkSquare2',
            shortcut: 'Ctrl+Shift+A',
            onTap: () => manager.selectAll(),
          ),
          MenuItem(
            label: '清除',
            icon: 'eraser',
            onTap: () => manager.clearTerminal(),
          ),
        ];
      },
      child: terminalContent,
    );
  }
}
