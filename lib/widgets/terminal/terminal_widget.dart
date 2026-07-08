import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:kterm/kterm.dart';

class TerminalWidget extends HookWidget {
  const TerminalWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final ptyRef = useRef<Pty?>(null);
    final subscriptionRef = useRef<StreamSubscription?>(null);
    final focusNode = useFocusNode();
    final controller = useMemoized(() => TerminalController());

    final terminal = useMemoized(() {
      final t = Terminal();
      t.onOutput = (String data) {
        ptyRef.value?.write(const Utf8Encoder().convert(data));
      };
      t.onResize = (int width, int height, int pixelWidth, int pixelHeight) {
        ptyRef.value?.resize(height, width);
      };
      return t;
    }, []);

    void startPty() {
      final shell = Platform.isWindows
          ? 'cmd.exe'
          : (Platform.environment['SHELL'] ?? '/bin/bash');

      final pty = Pty.start(
        shell,
        columns: terminal.viewWidth,
        rows: terminal.viewHeight,
      );

      ptyRef.value = pty;

      final sub = pty.output
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .listen((data) => terminal.write(data));
      subscriptionRef.value = sub;

      pty.exitCode.then((code) {
        terminal.write('\r\n[exit $code]\r\n');
      });
    }

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          startPty();
          focusNode.requestFocus();
        }
      });

      return () {
        subscriptionRef.value?.cancel();
        ptyRef.value?.kill();
      };
    }, const []);

    return ClipRect(
      child: TerminalView(
        terminal,
        controller: controller,
        autofocus: true,
      ),
    );
  }
}
