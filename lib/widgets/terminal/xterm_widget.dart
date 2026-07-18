import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:xterm2/xterm.dart';
import 'package:desktop_drop/desktop_drop.dart';

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
    final isDragging = useState(false);

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
    // 终端必须使用等宽字体
    final textStyle = useMemoized(
      () => TerminalStyle(
        fontSize: custom.typography.bodySize,
        fontFamily: defaultFontFamily,
      ),
      [custom.typography.bodySize],
    );

    String escapePath(String path) {
      if (path.contains(' ')) {
        if (Platform.isWindows) {
          return '"$path"';
        } else {
          return "'${path.replaceAll("'", "'\\''")}'";
        }
      }
      return path;
    }

    void onDrop(DropDoneDetails detail) {
      isDragging.value = false;
      if (detail.files.isEmpty) return;
      final paths = detail.files.map((f) => escapePath(f.path)).join(' ');
      ref.read(xtermManagerProvider(id).notifier).sendInput(paths);
    }

    // Single reusable handler instance (stateless).
    final deleteHandler = useMemoized(() => DeleteSelectionHandler());

    final terminalContent = DropTarget(
      onDragDone: onDrop,
      onDragEntered: (_) => isDragging.value = true,
      onDragExited: (_) => isDragging.value = false,
      child: Stack(
        children: [
          ClipRect(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: custom.spacing.sm),
              child: TerminalView(
                session.terminal,
                controller: session.controller,
                focusNode: focusNode.value,
                autofocus: visible,
                theme: theme,
                textStyle: textStyle,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent || event is KeyRepeatEvent) {
                    final keyboard = HardwareKeyboard.instance;
                    final isClipboardModifier =
                        keyboard.isControlPressed || keyboard.isMetaPressed;
                    final manager = ref.read(xtermManagerProvider(id).notifier);

                    final selection = session.controller.selection;
                    final hasSelection =
                        selection != null && !selection.isCollapsed;

                    if (isClipboardModifier &&
                        event.logicalKey == LogicalKeyboardKey.keyV) {
                      if (event is KeyDownEvent) {
                        unawaited(manager.pasteText());
                      }
                      return KeyEventResult.handled;
                    }

                    if (isClipboardModifier &&
                        event.logicalKey == LogicalKeyboardKey.keyX &&
                        hasSelection) {
                      if (event is KeyDownEvent) {
                        unawaited(manager.cutSelection());
                      }
                      return KeyEventResult.handled;
                    }

                    if (event is KeyDownEvent &&
                        deleteHandler.canHandle(event.logicalKey)) {
                      if (deleteHandler.handle(
                        session.terminal,
                        session.controller,
                      )) {
                        return KeyEventResult.handled;
                      }
                    }
                  }
                  return KeyEventResult.ignored;
                },
                onTapUp: (details, offset) {
                  ref.read(xtermManagerProvider(id).notifier).handleTap(offset);
                },
              ),
            ),
          ),
          // 拖拽覆盖层 - 淡入淡出
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !isDragging.value,
              child: AnimatedOpacity(
                opacity: isDragging.value ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const _DragOverlay(),
              ),
            ),
          ),
        ],
      ),
    );

    return MenuArea(
      builder: (context) {
        final manager = ref.read(xtermManagerProvider(id).notifier);
        final selection = session.controller.selection;
        final hasSelection = selection != null && !selection.isCollapsed;
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
            shortcut: 'Ctrl+X',
            enabled: hasSelection,
            onTap: () => manager.cutSelection(),
          ),
          MenuItem(
            label: '粘贴',
            icon: 'clipboardPaste',
            shortcut: 'Ctrl+V',
            onTap: () => manager.pasteText(),
          ),
          MenuItem(
            label: '粘贴文字',
            icon: 'clipboardType',
            onTap: () => manager.pasteAsPlainText(),
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

/// 拖拽文件到终端时的覆盖层
class _DragOverlay extends StatelessWidget {
  const _DragOverlay();

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Container(color: custom.colors.overlay);
  }
}
