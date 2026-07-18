import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_pty_new/flutter_pty_new.dart';
import 'package:xterm2/xterm.dart';

import 'package:agent/utils/shell_utils.dart';
import 'package:agent/widgets/terminal/shell_scripts.dart';

/// PTY process lifecycle + shell integration + cursor request file.
class PtyManager {
  PtyManager({
    required this.id,
    required this.terminal,
    required this.onOutput,
  });

  final String id;
  final Terminal terminal;

  /// Called with every chunk of output the PTY produces.
  final void Function(String text) onOutput;

  Pty? _pty;
  StreamSubscription? _ptySub;
  String? _integrationPath;
  String? _cursorRequestPath;
  bool _started = false;
  bool _shellInputActive = false;
  String _shellMarkerTail = '';
  String _shell = '';
  List<String> _args = [];
  int _exitCount = 0;
  DateTime? _lastExitTime;

  static const _crashWindow = Duration(seconds: 5);
  static const _maxConsecutiveCrashes = 3;
  static const _cursorMoveChord = '\x18\x07';
  static const _commandStartMarker = '\x1b]633;C';
  static const _commandEndMarker = '\x1b]633;D;';

  /// Whether the PTY is currently running.
  bool get isStarted => _started;

  /// Whether shell integration markers indicate the user is at a prompt.
  bool get isShellInputActive => _shellInputActive;

  /// Absolute path to the cursor request temp file, or `null` when
  /// shell integration has not been set up.
  String? get cursorRequestPath => _cursorRequestPath;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts the PTY with an optional [shell] override.
  void start({String shell = '', List<String> args = const []}) {
    if (_started) return;
    _started = true;
    _shellInputActive = false;
    _shellMarkerTail = '';
    _shell = shell;
    _args = args;

    final resolvedShell = resolveShell(shell);
    final env = Map<String, String>.from(Platform.environment);
    final resolvedArgs = _setupShellIntegration(resolvedShell, env);

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
        try {
          terminal.write(text);
        } catch (e) {
          debugPrint('[TERMINAL] xterm2 write error: $e');
        }
        onOutput(text);
      },
      onError: (error) {
        terminal.write('[error: $error]\r\n');
      },
      onDone: () {
        _ptySub = null;
      },
    );

    pty.exitCode.then((code) {
      _started = false;
      terminal.write('[exit $code]\r\n');
      _cleanup();
      _scheduleRestart(code);
    });
  }

  /// Sends raw [text] to the PTY process.
  void sendInput(String text) {
    _trackUserInput(text);
    _pty?.write(utf8.encode(text));
  }

  /// Attempts to move the cursor via shell integration (Ctrl+X,Ctrl+G).
  ///
  /// Returns `true` on success; the caller should fall back to ANSI sequences.
  bool tryCursorMove(int delta) {
    final path = _cursorRequestPath;
    if (path == null) return false;
    try {
      // bash/zsh `read` requires a line terminator to report success.
      File(path).writeAsStringSync('$delta\n');
      sendInput(_cursorMoveChord);
      return true;
    } catch (e) {
      debugPrint('[TERMINAL] cursor integration error: $e');
      _cleanupCursorRequest();
      return false;
    }
  }

  /// Tears down the PTY and integration artifacts.
  void dispose() {
    _cleanup();
  }

  // ---------------------------------------------------------------------------
  // Shell integration setup
  // ---------------------------------------------------------------------------

  List<String> _setupShellIntegration(String shell, Map<String, String> env) {
    final name = shell.split(RegExp(r'[\\/]')).last.toLowerCase();
    if (name == 'pwsh' || name == 'pwsh.exe' || name == 'powershell.exe') {
      return _setupPwshIntegration(shell);
    }
    if (name.contains('zsh')) {
      return _setupZshIntegration(env);
    }
    if (name.contains('bash')) {
      return _setupBashIntegration(env);
    }
    return _resolveArgs(shell, _args);
  }

  List<String> _setupPwshIntegration(String shell) {
    try {
      final tmpFile = File('${Directory.systemTemp.path}/agent-pwsh-$id.ps1');
      _integrationPath = tmpFile.path;
      final cursorPath = _createCursorRequestFile().replaceAll("'", "''");
      tmpFile.writeAsStringSync(pwshScript(cursorPath));

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

  List<String> _setupZshIntegration(Map<String, String> env) {
    try {
      final tmpDir = Directory.systemTemp.createTempSync('agent-zsh-');
      _integrationPath = tmpDir.path;
      final cursorPath = _createCursorRequestFile().replaceAll("'", "'\"'\"'");
      File('${tmpDir.path}/.zshrc').writeAsStringSync(zshScript(cursorPath));
      env['ZDOTDIR'] = tmpDir.path;
    } catch (e) {
      _cleanupCursorRequest();
      debugPrint('[TERMINAL] zsh integration error: $e');
    }
    return _resolveArgs('', const []);
  }

  List<String> _setupBashIntegration(Map<String, String> env) {
    try {
      final tmpFile = File('${Directory.systemTemp.path}/agent-bash-$id.sh');
      _integrationPath = tmpFile.path;
      final cursorPath = _createCursorRequestFile().replaceAll("'", "'\"'\"'");
      tmpFile.writeAsStringSync(bashScript(cursorPath));
      return ['--rcfile', tmpFile.path];
    } catch (e) {
      _cleanupCursorRequest();
      debugPrint('[TERMINAL] bash integration error: $e');
    }
    return _resolveArgs('', const []);
  }

  // ---------------------------------------------------------------------------
  // Cursor request temp file
  // ---------------------------------------------------------------------------

  String _createCursorRequestFile() {
    _cleanupCursorRequest();
    final file = File('${Directory.systemTemp.path}/agent-cursor-$id.txt');
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

  // ---------------------------------------------------------------------------
  // Crash recovery
  // ---------------------------------------------------------------------------

  void _scheduleRestart(int exitCode) {
    final now = DateTime.now();
    if (_lastExitTime != null &&
        now.difference(_lastExitTime!) < _crashWindow) {
      _exitCount++;
    } else {
      _exitCount = 1;
    }
    _lastExitTime = now;

    if (_exitCount > _maxConsecutiveCrashes) {
      terminal.write(
        '[terminal: too many consecutive exits ($_exitCount), press a key to retry]\r\n',
      );
      final originalOnOutput = terminal.onOutput;
      terminal.onOutput = (String data) {
        _exitCount = 0;
        terminal.onOutput = originalOnOutput;
        start(shell: _shell, args: _args);
      };
      return;
    }

    _started = false;
    start(shell: _shell, args: _args);
  }

  // ---------------------------------------------------------------------------
  // Shell input / output tracking
  // ---------------------------------------------------------------------------

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
      final isPartialStart =
          length < _commandStartMarker.length &&
          _commandStartMarker.startsWith(suffix);
      final isPartialEnd =
          length < _commandEndMarker.length &&
          _commandEndMarker.startsWith(suffix);
      if (isPartialStart || isPartialEnd) {
        _shellMarkerTail = suffix;
        break;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Internal cleanup
  // ---------------------------------------------------------------------------

  /// Tears down PTY and integration artifacts.
  /// Safe to call even if the process has already exited.
  void _cleanup() {
    _ptySub?.cancel();
    _ptySub = null;
    try {
      _pty?.kill();
    } catch (_) {
      // Already-exited process on some platforms may throw.
    }
    _pty = null;
    _started = false;
    _shellInputActive = false;
    _shellMarkerTail = '';
    _cleanupIntegration();
  }

  void _cleanupIntegration() {
    final path = _integrationPath;
    if (path != null) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        } else {
          final dir = Directory(path);
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        }
      } catch (_) {}
      _integrationPath = null;
    }
    _cleanupCursorRequest();
  }

  // ---------------------------------------------------------------------------
  // Argument resolution
  // ---------------------------------------------------------------------------

  static List<String> _resolveArgs(String shell, List<String> args) {
    if (args.isNotEmpty) return args;
    if (!Platform.isWindows) return [];
    final name = shell.split(RegExp(r'[\\/]')).last;
    if (name.isEmpty || name == 'cmd.exe') return [];
    final quoted = shell.contains(' ') ? '"$shell"' : shell;
    if (name == 'pwsh.exe') return ['-NoLogo', '-NoProfile', '-NoExit'];
    if (name == 'bash.exe') return ['/c', quoted, '--login', '-i'];
    return ['/c', quoted];
  }
}
