import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:kterm/kterm.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'provider.g.dart';

@riverpod
class TerminalRegistry extends _$TerminalRegistry {
  @override
  Set<String> build() => {};

  void add(String id) => state = {...state, id};
  void remove(String id) => state = {...state}..remove(id);
}

@riverpod
class TerminalManager extends _$TerminalManager {
  Pty? _pty;
  StreamSubscription? _subscription;
  final _outputController = StreamController<String>.broadcast();

  Stream<String> get output => _outputController.stream;

  @override
  Terminal build(String id) {
    ref.read(terminalRegistryProvider.notifier).add(id);
    ref.onDispose(() {
      ref.read(terminalRegistryProvider.notifier).remove(id);
    });
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
        .listen((bytes) {
      final text = utf8.decode(bytes);
      state.write(text);
      _outputController.add(text);
    });

    pty.exitCode.then((code) {
      state.write('\r\n[exit $code]\r\n');
    });
  }

  void sendInput(String text) {
    _pty?.write(const Utf8Encoder().convert(text));
  }

  @visibleForTesting
  void injectOutput(String text) {
    _outputController.add(text);
  }

  Future<String> execute(
    String command, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    final marker = RegExp(r'\x1b\]633;D;\d+(?:;\d+)?\x1b\\');
    StreamSubscription<String>? sub;

    sub = _outputController.stream.listen((chunk) {
      buffer.write(chunk);
      if (marker.hasMatch(buffer.toString())) {
        sub?.cancel();
        if (!completer.isCompleted) completer.complete(buffer.toString());
      }
    });

    sendInput('$command\r');

    if (timeout > Duration.zero) {
      Future.delayed(timeout, () {
        if (!completer.isCompleted) {
          sub?.cancel();
          completer.completeError(
            TimeoutException('Command timed out after $timeout', timeout),
          );
        }
      });
    }

    return completer.future;
  }

  void _kill() {
    _subscription?.cancel();
    _subscription = null;
    _pty?.kill();
    _pty = null;
  }

  void _dispose() {
    _outputController.close();
    _kill();
  }
}
