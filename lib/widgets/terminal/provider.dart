import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_pty_new/flutter_pty_new.dart';
import 'package:kterm/kterm.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'provider.g.dart';

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

class TerminalRegistry {
  final Set<String> _ids = {};
  Set<String> get ids => Set.unmodifiable(_ids);
  void add(String id) => _ids.add(id);
  void remove(String id) => _ids.remove(id);
}

final terminalRegistryProvider = Provider<TerminalRegistry>(
  (ref) => TerminalRegistry(),
);

@riverpod
class TerminalManager extends _$TerminalManager {
  TerminalRegistry? _registry;
  String? _id;
  Pty? _pty;
  StreamSubscription? _subscription;
  final _outputController = StreamController<String>.broadcast();
  bool _started = false;

  String _shell = '';
  List<String> _args = [];
  int _exitCount = 0;
  DateTime? _lastExitTime;
  static const Duration _crashWindow = Duration(seconds: 5);
  static const int _maxConsecutiveCrashes = 3;
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
    if (_pty == null && !_started) {
      _exitCount = 0;
      startPty(shell: _shell, args: _args);
      _pty?.write(const Utf8Encoder().convert(data));
      return;
    }
    _pty?.write(const Utf8Encoder().convert(data));
  }

  void _onResize(int w, int h, int pw, int ph) {
    _pty?.resize(h, w);
  }

  void startPty({String shell = '', List<String> args = const []}) {
    if (_started) return;
    _started = true;

    _shell = shell;
    _args = args;

    final resolvedShell = _resolveShell(shell);
    final env = Map<String, String>.from(Platform.environment);
    final resolvedArgs = _prepareIntegration(resolvedShell, env);

    Pty pty;
    try {
      pty = Pty.start(
        resolvedShell,
        arguments: resolvedArgs,
        columns: 80,
        rows: 24,
        environment: env,
      );
    } catch (e) {
      _started = false;
      state.write('\r\n[error: failed to start PTY - $e]\r\n');
      return;
    }

    _pty = pty;
    _exitCount = 0;

    _subscription = pty.output.cast<List<int>>().listen(
      (bytes) {
        final text = utf8.decode(bytes, allowMalformed: true);
        state.write(text);
        _outputController.add(text);
      },
      onError: (error) {
        state.write('\r\n[error: $error]\r\n');
      },
      onDone: () {
        _subscription = null;
      },
    );

    pty.exitCode.then((code) {
      if (!ref.mounted) return;
      state.write('\r\n[exit $code]\r\n');
      _cleanup();
      _scheduleRestart(code);
    });
  }

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
      state.write(
        '\r\n[terminal: too many consecutive exits ($_exitCount), press Enter to retry]\r\n',
      );
      return;
    }

    _started = false;
    if (!ref.mounted) return;
    startPty(shell: _shell, args: _args);
  }

  String? _integrationPath;

  /// 创建 shell 集成文件并返回修改后的参数（bash --rcfile 或 zsh 空参数）
  List<String> _prepareIntegration(String shell, Map<String, String> env) {
    final name = shell.split(RegExp(r'[\\/]')).last;
    if (name.contains('zsh')) {
      return _prepareZshIntegration(env);
    }
    if (name.contains('bash')) {
      return _prepareBashIntegration(env);
    }
    return _resolveArgs(shell, _args);
  }

  List<String> _prepareZshIntegration(Map<String, String> env) {
    try {
      final tmpDir = Directory.systemTemp.createTempSync('agent-zsh-');
      _integrationPath = tmpDir.path;

      final bs = String.fromCharCode(0x5c); // 反斜杠
      final dl = String.fromCharCode(0x24); // 美元符号
      final content = 'source ~/.zshrc 2>/dev/null\n'
          "precmd() { printf '${bs}033]633;D;'${dl}?'${bs}007'; }\n";
      File('${tmpDir.path}/.zshrc').writeAsStringSync(content);

      env['ZDOTDIR'] = tmpDir.path;
    } catch (e) {
      debugPrint('[TERMINAL] zsh integration error: $e');
    }
    return _resolveArgs('', const []);
  }

  List<String> _prepareBashIntegration(Map<String, String> env) {
    // TODO: implement bash integration
    return _resolveArgs('', const []);
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
    // OSC 633 序列: ESC ] 633 ; D ; exitcode BEL
    // 注意: 不能用 raw string，\x1B 需要是真正的 ESC 字节
    final osc633 = RegExp('\x1B]633;D;\\d+\x07');
    StreamSubscription<String>? sub;

    sub = _outputController.stream.listen((chunk) {
      buffer.write(chunk);
      final full = buffer.toString();
      if (osc633.hasMatch(full)) {
        sub?.cancel();
        if (!completer.isCompleted) {
          final all = buffer.toString();
          final cleaned = all.replaceAll(osc633, '').trim();
          completer.complete(cleaned);
        }
      }
    });
    sendInput('$command\r');

    if (timeout > Duration.zero) {
      Future.delayed(timeout, () {
        if (!completer.isCompleted) {
          sub?.cancel();
          completer.completeError(
            TimeoutException('Command timed out. Did you set up shell integration?'),
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

  void _kill() {
    _subscription?.cancel();
    _subscription = null;
    _pty?.kill();
    _pty = null;
  }

  void _dispose() {
    _registry?.remove(_id!);
    _outputController.close();
    _cleanupIntegration();
    _kill();
  }

  void _cleanupIntegration() {
    final path = _integrationPath;
    if (path == null) return;
    try {
      final d = Directory(path);
      if (d.existsSync()) d.deleteSync(recursive: true);
    } catch (_) {}
    _integrationPath = null;
  }
}
