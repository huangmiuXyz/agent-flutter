import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kyroon_pty/kyroon_pty.dart';
import 'package:kterm/kterm.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'provider.g.dart';

String _resolveShell(String shell) {
  if (shell.isNotEmpty) return shell;
  if (Platform.isWindows) return 'cmd.exe';
  final envShell = Platform.environment['SHELL'];
  if (envShell != null && envShell.isNotEmpty) return envShell;
  return File('/bin/zsh').existsSync() ? '/bin/zsh' : '/bin/bash';
}

List<String> _resolveArgs(String shell, List<String> args) {
  if (args.isNotEmpty) return args;
  if (!Platform.isWindows) return [];
  final name = shell.split(RegExp(r'[\\/]')).last;
  if (name.isEmpty || name == 'cmd.exe') return [];
  final quoted = shell.contains(' ') ? '"$shell"' : shell;
  if (name == 'pwsh.exe') return ['/c', quoted, '-NoLogo', '-NoProfile'];
  if (name == 'bash.exe') return ['/c', quoted, '--login', '-i'];
  return ['/c', quoted];
}

class TerminalRegistry {
  final Set<String> _ids = {};
  Set<String> get ids => Set.unmodifiable(_ids);
  void add(String id) => _ids.add(id);
  void remove(String id) => _ids.remove(id);
}

final terminalRegistryProvider = Provider<TerminalRegistry>((ref) => TerminalRegistry());

@riverpod
class TerminalManager extends _$TerminalManager {
  TerminalRegistry? _registry;
  String? _id;
  Pty? _pty;
  StreamSubscription? _subscription;
  final _outputController = StreamController<String>.broadcast();
  bool _started = false;

  Stream<String> get output => _outputController.stream;

  @override
  Terminal build(String id) {
    _id = id;
    _registry = ref.read(terminalRegistryProvider);
    _registry!.add(id);
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

  void startPty({String shell = '', List<String> args = const []}) {
    if (_started) return;
    _started = true;

    final pty = Pty.start(
      _resolveShell(shell),
      arguments: _resolveArgs(shell, args),
      columns: state.viewWidth,
      rows: state.viewHeight,
      environment: Map<String, String>.from(Platform.environment),
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
      if (!ref.mounted) return;
      state.write('\r\n[exit $code]\r\n');
    });
  }

  void sendInput(String text) {
    _pty?.write(const Utf8Encoder().convert(text));
  }

  void suspend() {
    _subscription?.pause();
  }

  void resume() {
    _subscription?.resume();
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
    _registry?.remove(_id!);
    _outputController.close();
    _kill();
  }
}
