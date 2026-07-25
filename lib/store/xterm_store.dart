import 'dart:async';

import 'package:flutter/services.dart';
import 'package:signals/signals.dart';
import 'package:xterm2/xterm.dart';

import 'package:agent/widgets/terminal/command_runner.dart';
import 'package:agent/widgets/terminal/key_handler.dart';
import 'package:agent/widgets/terminal/pty_manager.dart';

/// 单个终端会话管理器
class XtermSessionManager {
  final String id;
  final Terminal terminal;
  final TerminalController controller;
  final CommandRunner _commandRunner;
  final DeleteSelectionHandler _deleteSelectionHandler =
      DeleteSelectionHandler();
  PtyManager? _ptyManager;

  XtermSessionManager(this.id)
      : terminal = Terminal(maxLines: 5000),
        controller = TerminalController(),
        _commandRunner = CommandRunner();

  /// Starts the PTY process.
  void startPty({String shell = '', List<String> args = const []}) {
    _ptyManager = PtyManager(
      id: id,
      terminal: terminal,
      onOutput: _commandRunner.feedOutput,
    )..start(shell: shell, args: args);
  }

  /// Sends raw text to the PTY.
  void sendInput(String text) => _ptyManager?.sendInput(text);

  /// Handles a tap on the terminal at [offset].
  void handleTap(CellOffset offset) {
    MoveCursorHandler.handleTap(
      terminal,
      offset,
      onCursorMove: _sendCursorMove,
    );
  }

  /// Executes a command and returns its output.
  Future<String> execute(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _commandRunner.execute(
      command,
      sendInput: sendInput,
      timeout: timeout,
    );
  }

  // ── Clipboard & Selection ──

  Future<void> copySelection() async {
    final selection = controller.selection;
    if (selection == null) return;
    final text = terminal.buffer.getText(selection);
    if (text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  Future<void> pasteText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;

    if (controller.selection != null) {
      _deleteSelection();
    }
    terminal.paste(text);
    controller.clearSelection();
  }

  void selectAll() {
    final buf = terminal.buffer;
    controller.setSelection(
      buf.createAnchor(0, buf.height - terminal.viewHeight),
      buf.createAnchor(terminal.viewWidth, buf.height - 1),
      mode: SelectionMode.line,
    );
  }

  void clearTerminal() {
    terminal.write('\x1b[H\x1b[2J\x1b[3J');
  }

  Future<void> cutSelection() async {
    await copySelection();
    _deleteSelection();
  }

  Future<void> pasteAsPlainText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    final singleLine = text.replaceAll('\n', ' ').replaceAll('\r', ' ');
    terminal.paste(singleLine);
  }

  void deleteSelection() => _deleteSelection();

  void _deleteSelection() =>
      _deleteSelectionHandler.handle(terminal, controller);

  // ── Cursor movement ──

  void _sendCursorMove(CursorMoveRequest request) {
    final pty = _ptyManager;
    if (pty != null &&
        pty.isShellInputActive &&
        pty.tryCursorMove(request.delta)) {
      return;
    }
    terminal.onOutput?.call(request.fallbackInput);
  }

  // ── Cleanup ──

  void dispose() {
    _commandRunner.dispose();
    _ptyManager?.dispose();
    _ptyManager = null;
  }
}

/// 终端 Store — 管理所有终端实例
class XtermStore {
  static final instance = XtermStore._();
  XtermStore._();

  final _terminals = <String, XtermSessionManager>{};

  /// 活跃的终端 ID 集合
  final activeIds = signal(<String>{});

  /// 获取或创建指定 ID 的终端会话
  XtermSessionManager forId(String id) {
    return _terminals.putIfAbsent(id, () {
      final mgr = XtermSessionManager(id);
      activeIds.value = _terminals.keys.toSet();
      return mgr;
    });
  }

  /// 释放指定 ID 的终端会话
  void dispose(String id) {
    _terminals.remove(id)?.dispose();
    activeIds.value = _terminals.keys.toSet();
  }

  /// 释放所有终端会话
  void disposeAll() {
    for (final t in _terminals.values) { t.dispose(); }
    _terminals.clear();
    activeIds.value = {};
  }
}
