import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:kterm/kterm.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'provider.g.dart';

@riverpod
class TerminalManager extends _$TerminalManager {
  Pty? _pty;
  StreamSubscription? _subscription;

  @override
  Terminal build() {
    final t = Terminal();
    t.onOutput = _onOutput;
    t.onResize = _onResize;
    ref.onDispose(_dispose);
    return t;
  }

  void _onOutput(String data) {
    _pty?.write(const Utf8Encoder().convert(data));
  }

  void _onResize(int w, int h, int pw, int ph) {
    _pty?.resize(h, w);
  }

  void startPty() {
    _kill();
    final shell = Platform.isWindows
        ? 'cmd.exe'
        : (Platform.environment['SHELL'] ?? '/bin/bash');

    final pty = Pty.start(
      shell,
      columns: state.viewWidth,
      rows: state.viewHeight,
    );

    _pty = pty;

    _subscription = pty.output
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen((data) => state.write(data));

    pty.exitCode.then((code) {
      state.write('\r\n[exit $code]\r\n');
    });
  }

  void sendInput(String text) {
    _pty?.write(const Utf8Encoder().convert(text));
  }

  void _kill() {
    _subscription?.cancel();
    _subscription = null;
    _pty?.kill();
    _pty = null;
  }

  void _dispose() {
    _kill();
  }
}
