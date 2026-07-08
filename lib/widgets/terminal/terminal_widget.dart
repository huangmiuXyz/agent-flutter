import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

class TerminalWidget extends StatefulWidget {
  const TerminalWidget({super.key});

  @override
  State<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<TerminalWidget> {
  late final Terminal _terminal;
  Pty? _pty;
  StreamSubscription? _outputSub;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(
      onOutput: _onOutput,
      onResize: _onResize,
    );
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) _startPty();
    });
  }

  @override
  void dispose() {
    _outputSub?.cancel();
    _pty?.kill();
    super.dispose();
  }

  void _startPty() {
    final shell = Platform.isWindows
        ? 'cmd.exe'
        : (Platform.environment['SHELL'] ?? '/bin/bash');

    _pty = Pty.start(
      shell,
      columns: _terminal.viewWidth,
      rows: _terminal.viewHeight,
      workingDirectory: Platform.environment['HOME'] ?? '/',
    );

    _outputSub = _pty!.output
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen((data) => _terminal.write(data));

    _pty!.exitCode.then((code) {
      if (mounted) {
        _terminal.write('\r\n[exit $code]\r\n');
      }
    });
  }

  void _onOutput(String data) {
    _pty?.write(const Utf8Encoder().convert(data));
  }

  void _onResize(int width, int height, int pixelWidth, int pixelHeight) {
    _pty?.resize(height, width);
  }

  void restart() {
    _outputSub?.cancel();
    _pty?.kill();
    _terminal.write('\x1b[2J\x1b[H');
    _startPty();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: TerminalView(
        _terminal,
        autofocus: true,
        theme: TerminalThemes.defaultTheme,
      ),
    );
  }
}
