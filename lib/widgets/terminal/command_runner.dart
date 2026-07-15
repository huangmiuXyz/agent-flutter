import 'dart:async';

import 'package:ansi_strip/ansi_strip.dart';

/// Executes shell commands and captures their output.
///
/// Listens to the PTY output stream and waits for an OSC 633;D end-marker
/// that the shell integration scripts emit after each command completes.
class CommandRunner {
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
    final oscEnd = RegExp(r'\x1B\]633;D;-?\d+(?:\x07|\x1B\\)');
    final completer = Completer<String>();
    final buffer = StringBuffer();
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
