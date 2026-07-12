import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ansi_strip/ansi_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pty_new/flutter_pty_new.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xterm2/xterm.dart';

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
  if (name == 'pwsh.exe') return ['-NoLogo', '-NoProfile', '-NoExit'];
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
  final _outputController = StreamController<String>.broadcast();
  final Set<StreamSubscription<String>> _execSubs = {};
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
    final resolvedShell = _resolveShell(shell);
    final env = Map<String, String>.from(Platform.environment);
    final resolvedArgs = _prepareIntegration(resolvedShell, env);

    Pty pty;
    try {
      pty = Pty.start(
        resolvedShell,
        arguments: resolvedArgs,
        columns: terminal.viewWidth,
        rows: terminal.viewHeight,
        environment: env,
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
        final text = utf8.decode(bytes, allowMalformed: true);
        terminal.write(text);
        _outputController.add(text);
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
    _pty?.write(const Utf8Encoder().convert(text));
  }

  String? _integrationPath;

  List<String> _prepareIntegration(String shell, Map<String, String> env) {
    final name = shell.split(RegExp(r'[\\/]')).last.toLowerCase();
    if (name == 'pwsh' || name == 'pwsh.exe' || name == 'powershell.exe') {
      return _preparePowerShellIntegration(shell);
    }
    if (name.contains('zsh')) {
      return _prepareZshIntegration(env);
    }
    if (name.contains('bash')) {
      return _prepareBashIntegration(env);
    }
    return _resolveArgs(shell, _args);
  }

  List<String> _preparePowerShellIntegration(String shell) {
    try {
      final tmpFile = File(
        '${Directory.systemTemp.path}/agent-pwsh-${_id ?? 'unknown'}.ps1',
      );
      _integrationPath = tmpFile.path;

      final esc = String.fromCharCode(0x1b);
      final bel = String.fromCharCode(0x07);
      final content =
          r'''function global:prompt {
  $exitCode = if ($?) { 0 } elseif ($global:LASTEXITCODE) { $global:LASTEXITCODE } else { 1 }
  [Console]::Write("__ESC__]633;D;$exitCode__BEL__")
  "PS $($executionContext.SessionState.Path.CurrentLocation)> "
}
'''
              .replaceAll('__ESC__', esc)
              .replaceAll('__BEL__', bel);
      tmpFile.writeAsStringSync(content);

      final escapedPath = tmpFile.path.replaceAll("'", "''");
      return [
        '-NoLogo',
        '-NoProfile',
        '-NoExit',
        '-Command',
        ". '$escapedPath'",
      ];
    } catch (e) {
      debugPrint('[TERMINAL] PowerShell integration error: $e');
    }
    return _resolveArgs(shell, _args);
  }

  List<String> _prepareZshIntegration(Map<String, String> env) {
    try {
      final tmpDir = Directory.systemTemp.createTempSync('agent-zsh-');
      _integrationPath = tmpDir.path;

      final bs = String.fromCharCode(0x5c);
      final dl = String.fromCharCode(0x24);
      final content =
          'source ~/.zshrc 2>/dev/null\n'
          "preexec() { printf '${bs}033]633;C${bs}007'; }\n"
          "precmd() { printf '${bs}033]633;D;'${dl}?'${bs}007'; }\n";
      File('${tmpDir.path}/.zshrc').writeAsStringSync(content);

      env['ZDOTDIR'] = tmpDir.path;
    } catch (e) {
      debugPrint('[TERMINAL] zsh integration error: $e');
    }
    return _resolveArgs('', const []);
  }

  List<String> _prepareBashIntegration(Map<String, String> env) {
    try {
      final tmpFile = File(
        '${Directory.systemTemp.path}/agent-bash-${_id ?? 'unknown'}.sh',
      );
      _integrationPath = tmpFile.path;

      final bs = String.fromCharCode(0x5c);
      final dl = String.fromCharCode(0x24);
      final content =
          'source ~/.bashrc 2>/dev/null\n'
          "PROMPT_COMMAND='printf \"${bs}033]633;D;${dl}?${bs}007\"'\n";
      tmpFile.writeAsStringSync(content);

      return ['--rcfile', tmpFile.path];
    } catch (e) {
      debugPrint('[TERMINAL] bash integration error: $e');
    }
    return _resolveArgs('', const []);
  }

  Future<String> execute(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final oscEnd = RegExp(r'\x1B\]633;D;-?\d+(?:\x07|\x1B\\)');
    final completer = Completer<String>();
    final buffer = StringBuffer();
    StreamSubscription<String>? execSub;

    void done() {
      if (execSub != null) {
        _execSubs.remove(execSub);
        execSub?.cancel();
        execSub = null;
      }
    }

    execSub = _outputController.stream.listen(
      (text) {
        buffer.write(text);
        final full = buffer.toString();
        if (oscEnd.hasMatch(full)) {
          done();
          if (!completer.isCompleted) {
            final all = buffer.toString();
            final startIdx = all.lastIndexOf('\x1B]633;C\x07');
            final endIdx = all.lastIndexOf('\x1B]633;D;');
            var output = all;
            if (startIdx >= 0 && endIdx > startIdx) {
              final startEnd = all.indexOf('\x07', startIdx) + 1;
              output = all.substring(startEnd, endIdx);
            } else if (endIdx >= 0) {
              output = all.substring(0, endIdx);
            }
            var cleaned = stripAnsi(output);
            while (cleaned.contains('\x08')) {
              final idx = cleaned.indexOf('\x08');
              cleaned =
                  (idx > 0 ? cleaned.substring(0, idx - 1) : '') +
                  cleaned.substring(idx + 1);
            }
            cleaned = cleaned
                .replaceAll('\r\n', '\n')
                .replaceAll('\r', '\n')
                .trim();
            final resultLines = cleaned.split('\n')
              ..retainWhere((l) => !RegExp(r'^[%$#>]\s*$').hasMatch(l.trim()));
            cleaned = resultLines.join('\n').trim();
            completer.complete(cleaned);
          }
        }
      },
    );

    if (execSub case final sub?) {
      _execSubs.add(sub);
    }
    sendInput('$command\r');

    if (timeout > Duration.zero) {
      Future.delayed(timeout, () {
        if (!completer.isCompleted) {
          done();
          completer.completeError(
            TimeoutException(
              'Command timed out. Did you set up shell integration?',
            ),
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
    for (final subscription in _execSubs) {
      subscription.cancel();
    }
    _execSubs.clear();
    _outputController.close();
    _pty?.kill();
    _pty = null;
    _cleanupIntegration();
  }

  void _cleanupIntegration() {
    final path = _integrationPath;
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) {
        f.deleteSync();
      } else {
        final d = Directory(path);
        if (d.existsSync()) d.deleteSync(recursive: true);
      }
    } catch (_) {}
    _integrationPath = null;
  }
}
