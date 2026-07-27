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

  /// 确保 PTY 已启动（用于无 widget 挂载的场景，如前端工具调用）。
  /// 已启动则跳过，避免重复创建 PtyManager。
  void ensurePtyStarted({String shell = ''}) {
    if (_ptyManager != null) return;
    startPty(shell: shell);
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

/// 终端 Tab 元信息（用于 [XtermStore.tabs] 列表）
class TerminalTab {
  final String id;
  final String shell;
  const TerminalTab({required this.id, this.shell = ''});
}

/// 终端 Store — 管理所有终端实例 + Tab 列表 + 面板展开状态
class XtermStore {
  static final instance = XtermStore._();
  XtermStore._();

  /// 底层 terminal session 池：id → manager
  final _terminals = <String, XtermSessionManager>{};

  /// Tab 列表（有序），驱动 [TerminalTabs] UI
  final tabs = signal(<TerminalTab>[]);

  /// 当前激活的 tab id
  final activeTabId = signal<String?>(null);

  /// 终端面板"请求展开"计数器 — 每次 [openTab] 递增。
  ///
  /// 用计数器而非 bool，是为了让"用户手动折叠后再次调用工具"也能触发展开：
  /// bool 只在 false→true 变化时通知，而计数器每次递增都会通知监听者。
  final expandRequestCount = signal(0);

  /// 活跃的终端 ID 集合（兼容旧代码）
  final activeIds = signal(<String>{});

  /// 获取或创建指定 ID 的终端会话（仅创建底层 session，不创建 Tab）。
  XtermSessionManager forId(String id) {
    return _terminals.putIfAbsent(id, () {
      final mgr = XtermSessionManager(id);
      activeIds.value = _terminals.keys.toSet();
      return mgr;
    });
  }

  /// 检查指定 id 的 tab 是否存在（即终端是否未被关闭）。
  bool hasTab(String id) => tabs.value.any((t) => t.id == id);

  /// 添加/复用一个 tab 并激活，**不展开面板**。
  ///
  /// 用于应用启动时创建默认 tab、用户双击新增 tab 等场景 —— 这些场景下
  /// 面板状态由用户控制（已展开就显示，已折叠就保持折叠）。
  void addTab(String id, {String shell = ''}) {
    final existing = tabs.value.indexWhere((t) => t.id == id);
    if (existing < 0) {
      tabs.value = [...tabs.value, TerminalTab(id: id, shell: shell)];
    }
    activeTabId.value = id;
    // 确保 session 存在（PTY 启动由 widget mount 或 handler 触发）
    forId(id);
  }

  /// 打开一个 tab：如果 id 存在则复用并激活，不存在则创建并激活。
  /// **同时自动展开终端面板**。
  ///
  /// 用于前端工具调用（如 `simulated_terminal`）—— AI 调用工具时
  /// 需要让用户看到执行过程。
  void openTab(String id, {String shell = ''}) {
    addTab(id, shell: shell);
    // 递增计数器触发展开（即使面板已展开也会通知，确保重复调用有效）
    expandRequestCount.value++;
  }

  /// 关闭一个 tab 并销毁底层 session。
  void closeTab(String id) {
    tabs.value = tabs.value.where((t) => t.id != id).toList();
    _terminals.remove(id)?.dispose();
    activeIds.value = _terminals.keys.toSet();
    if (activeTabId.value == id) {
      activeTabId.value = tabs.value.isNotEmpty ? tabs.value.last.id : null;
    }
  }

  /// 设置激活的 tab（点击 tab 时调用）。
  void setActiveTab(String id) {
    if (tabs.value.any((t) => t.id == id)) {
      activeTabId.value = id;
    }
  }

  /// 请求展开终端面板（递增计数器，触发监听者执行展开）
  void expandPanel() => expandRequestCount.value++;

  /// 折叠终端面板（仅语义占位，实际折叠由用户拖拽控制）
  void collapsePanel() {}

  /// 释放指定 ID 的终端会话（兼容旧代码）
  void dispose(String id) {
    _terminals.remove(id)?.dispose();
    activeIds.value = _terminals.keys.toSet();
    tabs.value = tabs.value.where((t) => t.id != id).toList();
    if (activeTabId.value == id) {
      activeTabId.value = tabs.value.isNotEmpty ? tabs.value.last.id : null;
    }
  }

  /// 释放所有终端会话
  void disposeAll() {
    for (final t in _terminals.values) {
      t.dispose();
    }
    _terminals.clear();
    activeIds.value = {};
    tabs.value = [];
    activeTabId.value = null;
  }
}
