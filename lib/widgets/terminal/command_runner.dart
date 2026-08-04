import 'dart:async';

import 'package:ansi_strip/ansi_strip.dart';

/// Executes shell commands and captures their output.
///
/// Listens to the PTY output stream and waits for an OSC 633;D end-marker
/// that the shell integration scripts emit after each command completes.
class CommandRunner {
  static final _oscEndMarker = RegExp(r'\x1B\]633;D;-?\d+(?:\x07|\x1B\\)');
  static final _promptPattern = RegExp(r'^[%$#>]\s*$');

  /// 结束标记匹配窗口大小。
  ///
  /// 只对输出尾部窗口做正则匹配，避免大输出（如 `ls -R .`）时每个 chunk
  /// 都对已累积的完整输出做全量扫描（O(n²)），阻塞 UI isolate。
  static const _scanWindowSize = 8192;
  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  final Set<StreamSubscription<String>> _execSubs = {};

  /// The broadcast stream of all raw terminal output.
  Stream<String> get outputStream => _outputController.stream;

  /// Feeds a chunk of PTY output into the runner.
  void feedOutput(String text) {
    _outputController.add(text);
  }

  /// Sends [command] to the terminal and returns the cleaned output once
  /// the shell end-marker is detected.
  Future<String> execute(
    String command, {
    required void Function(String text) sendInput,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    var tail = '';
    StreamSubscription<String>? execSub;
    Timer? timeoutTimer;

    void done() {
      timeoutTimer?.cancel();
      timeoutTimer = null;
      if (execSub != null) {
        _execSubs.remove(execSub);
        execSub?.cancel();
        execSub = null;
      }
    }

    execSub = _outputController.stream.listen((text) {
      buffer.write(text);
      // 只扫描输出尾部窗口（固定大小），跨 chunk 的标记也能命中；
      // 匹配成功后再做一次全量提取，避免每个 chunk 都 O(n) 复制+扫描。
      tail += text;
      if (tail.length > _scanWindowSize) {
        tail = tail.substring(tail.length - _scanWindowSize);
      }
      if (_oscEndMarker.hasMatch(tail)) {
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
          // 单遍处理 backspace（\x08）：删除前一个字符，避免
          // while + substring 在大输出下退化为 O(n²)。
          final outChars = <String>[];
          for (final ch in cleaned.split('')) {
            if (ch == '\x08') {
              if (outChars.isNotEmpty) outChars.removeLast();
            } else {
              outChars.add(ch);
            }
          }
          cleaned = outChars.join();
          cleaned = cleaned
              .replaceAll('\r\n', '\n')
              .replaceAll('\r', '\n')
              .trim();
          final resultLines = cleaned.split('\n')
            ..retainWhere((l) => !_promptPattern.hasMatch(l.trim()));
          cleaned = resultLines.join('\n').trim();

          // 没有开始标记时，去掉开头的命令回显
          if (startIdx < 0) {
            final cmdText = command.trim();
            if (cleaned.startsWith(cmdText)) {
              cleaned = cleaned.substring(cmdText.length).trimLeft();
            }
          }

          completer.complete(cleaned);
        }
      }
    });

    if (execSub case final sub?) {
      _execSubs.add(sub);
    }
    sendInput('$command\r');

    if (timeout > Duration.zero) {
      timeoutTimer = Timer(timeout, () {
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

  /// Cancels all active execution subscriptions.
  void dispose() {
    for (final sub in _execSubs) {
      sub.cancel();
    }
    _execSubs.clear();
    _outputController.close();
  }
}
