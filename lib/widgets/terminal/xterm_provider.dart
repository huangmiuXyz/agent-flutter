import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ansi_strip/ansi_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pty_new/flutter_pty_new.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xterm2/xterm.dart';

import 'package:agent/widgets/terminal/key_handler.dart';

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
  bool _shellInputActive = false;
  String _shellMarkerTail = '';

  String _shell = '';
  List<String> _args = [];
  int _exitCount = 0;
  DateTime? _lastExitTime;
  static const Duration _crashWindow = Duration(seconds: 5);
  static const int _maxConsecutiveCrashes = 3;
  static const String _cursorMoveChord = '\x18\x07';
  static const String _commandStartMarker = '\x1b]633;C';
  static const String _commandEndMarker = '\x1b]633;D;';

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
    _shellInputActive = false;
    _shellMarkerTail = '';

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
      _trackUserInput(data);
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
        _trackShellOutput(text);
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
    _trackUserInput(text);
    _pty?.write(const Utf8Encoder().convert(text));
  }

  void _trackUserInput(String text) {
    if (text.contains('\r') || text.contains('\n')) {
      _shellInputActive = false;
    }
  }

  void _trackShellOutput(String text) {
    final combined = '$_shellMarkerTail$text';
    final commandStart = combined.lastIndexOf(_commandStartMarker);
    final commandEnd = combined.lastIndexOf(_commandEndMarker);
    if (commandStart >= 0 || commandEnd >= 0) {
      _shellInputActive = commandEnd > commandStart;
    }

    _shellMarkerTail = '';
    for (int length = _commandEndMarker.length - 1; length > 0; length--) {
      if (length > combined.length) continue;
      final suffix = combined.substring(combined.length - length);
      final isPartialStart = length < _commandStartMarker.length &&
          _commandStartMarker.startsWith(suffix);
      final isPartialEnd = length < _commandEndMarker.length &&
          _commandEndMarker.startsWith(suffix);
      if (isPartialStart || isPartialEnd) {
        _shellMarkerTail = suffix;
        break;
      }
    }
  }

  void handleTap(CellOffset offset) {
    TapHandlerFactory.handleTap(
      state.terminal,
      offset,
      onCursorMove: _sendCursorMove,
    );
  }

  void _sendCursorMove(CursorMoveRequest request) {
    final requestPath = _cursorRequestPath;
    if (requestPath != null && _shellInputActive) {
      try {
        File(requestPath).writeAsStringSync('${request.delta}');
        sendInput(_cursorMoveChord);
        return;
      } catch (error) {
        debugPrint('[TERMINAL] cursor integration error: $error');
        _cleanupCursorRequest();
      }
    }

    state.terminal.onOutput?.call(request.fallbackInput);
  }

  String? _integrationPath;
  String? _cursorRequestPath;

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
      final cursorPath = _createCursorRequestFile().replaceAll("'", "''");

      final esc = String.fromCharCode(0x1b);
      final bel = String.fromCharCode(0x07);
      final content =
          r'''function global:prompt {
  $exitCode = if ($?) { 0 } elseif ($global:LASTEXITCODE) { $global:LASTEXITCODE } else { 1 }
  [Console]::Write("__ESC__]633;D;$exitCode__BEL__")
  "PS $($executionContext.SessionState.Path.CurrentLocation)> "
}

if (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) {
  Set-PSReadLineKeyHandler -Chord 'Ctrl+x,Ctrl+g' -ScriptBlock {
    try {
      $delta = [int](Get-Content -LiteralPath '__CURSOR_PATH__' -Raw)
      if ($delta -lt 0) {
        [Microsoft.PowerShell.PSConsoleReadLine]::BackwardChar($null, -$delta)
      } elseif ($delta -gt 0) {
        [Microsoft.PowerShell.PSConsoleReadLine]::ForwardChar($null, $delta)
      }
    } catch {}
  }
}
'''
              .replaceAll('__ESC__', esc)
              .replaceAll('__BEL__', bel)
              .replaceAll('__CURSOR_PATH__', cursorPath);
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
      _cleanupCursorRequest();
      debugPrint('[TERMINAL] PowerShell integration error: $e');
    }
    return _resolveArgs(shell, _args);
  }

  List<String> _prepareZshIntegration(Map<String, String> env) {
    try {
      final tmpDir = Directory.systemTemp.createTempSync('agent-zsh-');
      _integrationPath = tmpDir.path;
      final cursorPath = _createCursorRequestFile().replaceAll("'", "'\"'\"'");

      final content =
          r'''source ~/.zshrc 2>/dev/null

__agent_cursor_move() {
  local delta
  IFS= read -r delta < '__CURSOR_PATH__' || return
  [[ $delta == <-> || $delta == -<-> ]] || return
  (( CURSOR += delta ))
  (( CURSOR < 0 )) && CURSOR=0
  (( CURSOR > ${#BUFFER} )) && CURSOR=${#BUFFER}
}
zle -N __agent_cursor_move
bindkey -M emacs '^X^G' __agent_cursor_move 2>/dev/null
bindkey -M viins '^X^G' __agent_cursor_move 2>/dev/null

preexec() { printf '\033]633;C\007'; }
precmd() { printf '\033]633;D;%s\007' $?; }
'''
              .replaceAll('__CURSOR_PATH__', cursorPath);
      File('${tmpDir.path}/.zshrc').writeAsStringSync(content);

      env['ZDOTDIR'] = tmpDir.path;
    } catch (e) {
      _cleanupCursorRequest();
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
      final cursorPath = _createCursorRequestFile().replaceAll("'", "'\"'\"'");

      final content =
          r'''source ~/.bashrc 2>/dev/null

__agent_readline_prefix() {
  local LC_ALL=C
  __agent_prefix=${READLINE_LINE:0:READLINE_POINT}
}

__agent_readline_byte_length() {
  local LC_ALL=C
  __agent_length=${#__agent_target}
}

__agent_cursor_move() {
  local delta target character_length
  IFS= read -r delta < '__CURSOR_PATH__' || return
  [[ $delta =~ ^-?[0-9]+$ ]] || return

  __agent_readline_prefix
  target=$((${#__agent_prefix} + delta))
  character_length=${#READLINE_LINE}
  (( target < 0 )) && target=0
  (( target > character_length )) && target=$character_length

  __agent_target=${READLINE_LINE:0:target}
  __agent_readline_byte_length
  READLINE_POINT=$__agent_length
}
bind -m emacs-standard -x '"\C-x\C-g":__agent_cursor_move' 2>/dev/null
bind -m vi-insertion -x '"\C-x\C-g":__agent_cursor_move' 2>/dev/null

PROMPT_COMMAND='printf "\033]633;D;$?\007"'
'''
              .replaceAll('__CURSOR_PATH__', cursorPath);
      tmpFile.writeAsStringSync(content);

      return ['--rcfile', tmpFile.path];
    } catch (e) {
      _cleanupCursorRequest();
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
    _shellInputActive = false;
    _shellMarkerTail = '';
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

  String _createCursorRequestFile() {
    _cleanupCursorRequest();
    final file = File(
      '${Directory.systemTemp.path}/agent-cursor-${_id ?? 'unknown'}.txt',
    );
    file.writeAsStringSync('0');
    _cursorRequestPath = file.path;
    return file.path;
  }

  void _cleanupCursorRequest() {
    final path = _cursorRequestPath;
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
    _cursorRequestPath = null;
  }

  void _cleanupIntegration() {
    final path = _integrationPath;
    if (path != null) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        } else {
          final directory = Directory(path);
          if (directory.existsSync()) directory.deleteSync(recursive: true);
        }
      } catch (_) {}
      _integrationPath = null;
    }
    _cleanupCursorRequest();
  }
}
