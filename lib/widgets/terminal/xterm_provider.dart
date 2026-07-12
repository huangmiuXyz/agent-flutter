import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xterm2/xterm.dart';

import 'package:agent/widgets/terminal/command_runner.dart';
import 'package:agent/widgets/terminal/key_handler.dart';
import 'package:agent/widgets/terminal/pty_manager.dart';

part 'xterm_provider.g.dart';

/// A terminal session bundle.
class XtermSession {
  final Terminal terminal;
  final TerminalController controller;
  const XtermSession({required this.terminal, required this.controller});
}

/// Global registry of active terminal IDs.
class XtermRegistry {
  final Set<String> _ids = {};
  Set<String> get ids => Set.unmodifiable(_ids);
  void add(String id) => _ids.add(id);
  void remove(String id) => _ids.remove(id);
}

final xtermRegistryProvider = Provider<XtermRegistry>((ref) => XtermRegistry());

// ---------------------------------------------------------------------------
// Per-terminal provider
// ---------------------------------------------------------------------------

@riverpod
class XtermManager extends _$XtermManager {
  XtermRegistry? _registry;
  String? _id;
  PtyManager? _ptyManager;
  CommandRunner? _commandRunner;

  @override
  XtermSession build(String id) {
    _id = id;
    _registry = ref.read(xtermRegistryProvider);
    _registry!.add(id);

    final terminal = Terminal(maxLines: 5000);
    final controller = TerminalController();
    _commandRunner = CommandRunner();

    _ptyManager = PtyManager(
      id: id,
      terminal: terminal,
      onOutput: _commandRunner!.feedOutput,
    );

    ref.onDispose(() {
      _registry?.remove(_id!);
      _dispose();
    });

    return XtermSession(terminal: terminal, controller: controller);
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Starts the PTY process.
  void startPty({String shell = '', List<String> args = const []}) {
    _ptyManager?.start(shell: shell, args: args);
  }

  /// Sends raw text to the PTY.
  void sendInput(String text) {
    _ptyManager?.sendInput(text);
  }

  /// Handles a tap on the terminal at [offset].
  void handleTap(CellOffset offset) {
    MoveCursorHandler.handleTap(
      state.terminal,
      offset,
      onCursorMove: _sendCursorMove,
    );
  }

  /// Executes a command and returns its output.
  Future<String> execute(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    final runner = _commandRunner;
    if (runner == null) {
      return Future.error('Terminal not initialized');
    }
    return runner.execute(command, sendInput: sendInput, timeout: timeout);
  }

  // ---------------------------------------------------------------------------
  // Cursor movement
  // ---------------------------------------------------------------------------

  void _sendCursorMove(CursorMoveRequest request) {
    final pty = _ptyManager;
    if (pty != null &&
        pty.isShellInputActive &&
        pty.tryCursorMove(request.delta)) {
      return;
    }

    // Fallback: send ANSI cursor movement sequences.
    state.terminal.onOutput?.call(request.fallbackInput);
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  void _dispose() {
    _commandRunner?.dispose();
    _commandRunner = null;
    _ptyManager?.dispose();
    _ptyManager = null;
  }
}
