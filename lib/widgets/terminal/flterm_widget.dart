import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flterm/flterm.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/terminal/flterm_provider.dart';
import 'package:agent/widgets/terminal/terminal_palette.dart';

class FltermTerminalWidget extends HookConsumerWidget {
  const FltermTerminalWidget({
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
    final controller = ref.watch(fltermManagerProvider(id));
    final custom = CustomTheme.of(context);
    final focusNode = useRef(FocusNode());

    useEffect(() {
      ref.read(fltermManagerProvider(id).notifier).startPty(shell: shell);
      return () {};
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
        controller: controller,
        focusNode: focusNode.value,
        autofocus: false,
        theme: TerminalTheme(
          palette: ref.watch(fltermPaletteProvider),
          fontFamily: 'Menlo',
          fontSize: custom.fontSizeBody,
          fontWeight: FontWeight.w400,
          fontFamilyFallback: const [
            'Menlo',
            'Consolas',
            'Courier New',
            'monospace',
          ],
          cursor: const CursorTheme(shape: CursorShape.block),
          selection: const SelectionTheme(
            background: DynamicColor.fixed(Color(0x40000000)),
          ),
        ),
      ),
    );
  }
}
