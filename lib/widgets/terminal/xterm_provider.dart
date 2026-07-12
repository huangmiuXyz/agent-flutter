import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_pty_new/flutter_pty_new.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xterm/xterm.dart';

part 'xterm_provider.g.dart';

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

class XtermSession {
  final Terminal terminal;
  final TerminalController controller;
  const XtermSession({required this.terminal, required this.controller});
}

class XtermRegistry {
  final Set<String> _ids = {};
  Set<String> get ids => Set.unmodifiable(_ids);
  void add(String id) => _ids.add(id);
  void remove(String id) => _ids.remove(id);
}

final xtermRegistryProvider = Provider<XtermRegistry>((ref) => XtermRegistry());

@riverpod
class XtermManager extends _$XtermManager {
  XtermRegistry? _registry;
  String? _id;
  Pty? _pty;
  StreamSubscription? _ptySub;
  StreamSubscription? _execSub;
  bool _started = false;

  String _shell = '';
  List<String> _args = [];
  int _exitCount = 0;
  DateTime? _lastExitTime;
  static const Duration _crashWindow = Duration(seconds: 5);
  static const int _maxConsecutiveCrashes = 3;

  @override
  XtermSession build(String id) {
    _id = id;
    _registry = ref.read(xtermRegistryProvider);
    _registry!.add(id);

    final terminal = Terminal(maxLines: 5000);
    final controller = TerminalController();

    ref.onDispose(() {
      _registry?.remove(_id!);
      _dispose();
    });

    return XtermSession(terminal: terminal, controller: controller);
  }

  void startPty({String shell = '', List<String> args = const []}) {
    if (_started) return;
    _started = true;

    _shell = shell;
    _args = args;

    final terminal = state.terminal;

    Pty pty;
    try {
      pty = Pty.start(
        _resolveShell(shell),
        arguments: _resolveArgs(shell, args),
        columns: terminal.viewWidth,
        rows: terminal.viewHeight,
        environment: Map<String, String>.from(Platform.environment),
      );
    } catch (e) {
      _started = false;
      terminal.write('[error: failed to start PTY - $e]\r\n');
      return;
    }

    _pty = pty;

    terminal.onOutput = (String data) {
      if (!_started) return;
      try {
        pty.write(utf8.encode(data));
      } catch (_) {}
    };

    terminal.onResize = (int w, int h, int pw, int ph) {
      pty.resize(h, w);
    };

    _ptySub = pty.output.cast<List<int>>().listen(
      (List<int> bytes) {
        terminal.write(utf8.decode(bytes, allowMalformed: true));
      },
      onError: (error) {
        terminal.write('[error: $error]\r\n');
      },
      onDone: () {
        _ptySub = null;
      },
    );

    pty.exitCode.then((code) {
      if (!ref.mounted) return;
      _started = false;
      terminal.write('[exit $code]\r\n');
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
      state.terminal.write(
          '[terminal: too many consecutive exits ($_exitCount), press a key to retry]\r\n');
      final originalOnOutput = state.terminal.onOutput;
      state.terminal.onOutput = (String data) {
        if (ref.mounted) {
          _exitCount = 0;
          state.terminal.onOutput = originalOnOutput;
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
    state.terminal.textInput(text);
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

    state.terminal.textInput('$command\recho $marker\r');

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
    _ptySub?.cancel();
    _ptySub = null;
    _pty?.kill();
    _pty = null;
    _started = false;
  }

  void _dispose() {
    _ptySub?.cancel();
    _ptySub = null;
    _execSub?.cancel();
    _execSub = null;
    _pty?.kill();
    _pty = null;
  }
}
