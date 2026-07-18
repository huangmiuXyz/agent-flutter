import 'dart:async';

import 'package:flutter/services.dart';
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
  // Clipboard & Selection
  // ---------------------------------------------------------------------------

  /// Copies the current selection to the system clipboard.
  Future<void> copySelection() async {
    final selection = state.controller.selection;
    if (selection == null) return;
    final text = state.terminal.buffer.getText(selection);
    if (text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  /// Pastes text from the system clipboard into the terminal.
  ///
  /// When terminal text is selected, replaces that selection before inserting
  /// the clipboard text.
  Future<void> pasteText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;

    if (state.controller.selection != null) {
      _deleteSelection();
    }
    state.terminal.paste(text);
    state.controller.clearSelection();
  }

  /// Selects all visible content in the terminal.
  void selectAll() {
    final buf = state.terminal.buffer;
    state.controller.setSelection(
      buf.createAnchor(0, buf.height - state.terminal.viewHeight),
      buf.createAnchor(state.terminal.viewWidth, buf.height - 1),
      mode: SelectionMode.line,
    );
  }

  /// Clears the terminal screen and scrollback buffer directly.
  void clearTerminal() {
    state.terminal.write('\x1b[H\x1b[2J\x1b[3J');
  }

  /// Cuts the current selection: copies to clipboard then deletes.
  Future<void> cutSelection() async {
    await copySelection();
    _deleteSelection();
  }

  /// Pastes clipboard text as a single line (newlines → spaces).
  Future<void> pasteAsPlainText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    final singleLine = text.replaceAll('\n', ' ').replaceAll('\r', ' ');
    state.terminal.paste(singleLine);
  }

  /// Deletes the current selection without copying to clipboard.
  void deleteSelection() {
    _deleteSelection();
  }

  void _deleteSelection() {
    DeleteSelectionHandler().handle(state.terminal, state.controller);
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
