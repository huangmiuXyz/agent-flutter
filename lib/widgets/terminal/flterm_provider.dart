import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flterm/flterm.dart';
import 'package:flutter_pty_new/flutter_pty_new.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'flterm_provider.g.dart';

String _resolveShell(String shell) {
  if (shell.isNotEmpty) return shell;
  if (Platform.isWindows) return 'pwsh.exe';
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

class FltermRegistry {
  final Set<String> _ids = {};
  Set<String> get ids => Set.unmodifiable(_ids);
  void add(String id) => _ids.add(id);
  void remove(String id) => _ids.remove(id);
}

final fltermRegistryProvider = Provider<FltermRegistry>((ref) => FltermRegistry());

@riverpod
class FltermManager extends _$FltermManager {
  FltermRegistry? _registry;
  String? _id;
  Pty? _pty;
  StreamSubscription? _subscription;
  StreamSubscription? _execSub;
  bool _started = false;

  String _shell = '';
  List<String> _args = [];
  int _exitCount = 0;
  DateTime? _lastExitTime;
  static const Duration _crashWindow = Duration(seconds: 5);
  static const int _maxConsecutiveCrashes = 3;

  @override
  TerminalController build(String id) {
    _id = id;
    _registry = ref.read(fltermRegistryProvider);
    _registry!.add(id);
    final controller = TerminalController(
      config: TerminalConfig(scrollbackLimit: 5000),
    );
    ref.onDispose(() {
      _registry?.remove(_id!);
      _dispose();
    });
    return controller;
  }

  void startPty({String shell = '', List<String> args = const []}) {
    if (_started) return;
    _started = true;

    _shell = shell;
    _args = args;

    final controller = state;

    Pty pty;
    try {
      pty = Pty.start(
        _resolveShell(shell),
        arguments: _resolveArgs(shell, args),
        columns: 80,
        rows: 24,
        environment: Map<String, String>.from(Platform.environment),
      );
    } catch (e) {
      _started = false;
      controller.write(utf8.encode('[error: failed to start PTY - $e]\r\n'));
      return;
    }

    _pty = pty;

    controller.onOutput = (Uint8List bytes) {
      if (!_started) return;
      try {
        pty.write(bytes);
      } catch (_) {}
    };

    controller.onResize = (int cols, int rows) {
      pty.resize(rows, cols);
    };

    _subscription = pty.output
        .cast<List<int>>()
        .listen(
      (List<int> bytes) {
        controller.write(Uint8List.fromList(bytes));
      },
      onError: (error) {
        controller.write(utf8.encode('[error: $error]\r\n'));
      },
      onDone: () {
        _subscription = null;
      },
    );

    pty.exitCode.then((code) {
      if (!ref.mounted) return;
      _started = false;
      controller.write(utf8.encode('[exit $code]\r\n'));
      _cleanup();
      _scheduleRestart(code);
    });
  }

  void _scheduleRestart(int exitCode) {
    final now = DateTime.now();
    if (_lastExitTime != null && now.difference(_lastExitTime!) < _crashWindow) {
      _exitCount++;
    } else {
      _exitCount = 1;
    }
    _lastExitTime = now;

    if (_exitCount > _maxConsecutiveCrashes) {
      state.write(utf8.encode(
          '[terminal: too many consecutive exits ($_exitCount), press a key to retry]\r\n'));
      final originalOnOutput = state.onOutput;
      state.onOutput = (Uint8List bytes) {
        if (ref.mounted) {
          _exitCount = 0;
          state.onOutput = originalOnOutput;
          startPty(shell: _shell, args: _args);
        }
      };
      return;
    }

    _started = false;
    if (!ref.mounted) return;
    startPty(shell: _shell, args: _args);
  }

  void sendInput(String text) {
    if (_pty != null) {
      state.sendText(text);
    }
  }

  Future<String> execute(
    String command, {
    Duration timeout = const Duration(minutes: 2),
    String marker = 'EXEC_DONE',
  }) async {
    _execSub?.cancel();
    final completer = Completer<String>();
    final buffer = StringBuffer();

    void done() {
      _execSub?.cancel();
      _execSub = null;
    }

    _execSub = _pty?.output.cast<List<int>>().listen(
      (bytes) {
        final text = utf8.decode(bytes, allowMalformed: true);
        buffer.write(text);
        if (text.contains(marker)) {
          done();
          if (!completer.isCompleted) completer.complete(buffer.toString());
        }
      },
    );

    state.sendText('$command\r\necho $marker\r');

    if (timeout > Duration.zero) {
      Future.delayed(timeout, () {
        if (!completer.isCompleted) {
          done();
          completer.completeError(
            TimeoutException('Command timed out after $timeout', timeout),
          );
        }
      });
    }

    return completer.future;
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _pty?.kill();
    _pty = null;
    _started = false;
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
    _execSub?.cancel();
    _execSub = null;
    _pty?.kill();
    _pty = null;
  }
}
