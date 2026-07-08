import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kterm/kterm.dart';

import 'provider.dart';

class TerminalWidget extends HookConsumerWidget {
  const TerminalWidget({super.key, this.terminalId = 'default'});

  final String terminalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminal = ref.watch(terminalManagerProvider(terminalId));
    final controller = useMemoized(() => TerminalController());

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(terminalManagerProvider(terminalId).notifier).startPty();
      });
      return null;
    }, [terminalId]);

    return ClipRect(
      child: TerminalView(
        terminal,
        controller: controller,
        autofocus: true,
      ),
    );
  }
}
