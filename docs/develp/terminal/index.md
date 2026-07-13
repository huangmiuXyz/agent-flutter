# 内置终端开发指南

## 概述

该项目基于 `xterm2` 包实现了内置终端模拟器。终端通过 `flutter_pty_new` 与系统 Shell（PowerShell/zsh/bash）通信，并实现了点击文字跳转光标、文本选择与删除等交互功能。

终端管理采用 Riverpod 架构，`XtermManager` 作为 per-terminal provider，内部委托 `PtyManager` 处理 PTY 生命周期和 Shell 集成，委托 `CommandRunner` 处理命令执行与输出捕获。

---

## 架构总览

```
┌─────────────────────────────────────────────────┐
│              XtermTerminalWidget                 │  (xterm_widget.dart)
│  ┌───────────────────────────────────────────┐   │
│  │             TerminalView (xterm2)          │   │
│  │  ┌─────────────────────────────────────┐   │   │
│  │  │         RenderTerminal               │   │   │
│  │  │  · 字符布局/渲染                     │   │   │
│  │  │  · getCellOffset() 像素→单元格坐标    │   │   │
│  │  │  · 光标渲染、选择渲染                 │   │   │
│  │  └─────────────────────────────────────┘   │   │
│  │  ┌─────────────────────────────────────┐   │   │
│  │  │       GestureHandler                 │   │   │
│  │  │  · 单击/双击/长按/拖拽               │   │   │
│  │  └─────────────────────────────────────┘   │   │
│  └───────────────────────────────────────────┘   │
│                                                   │
│  onTapUp → XtermManager.handleTap()                │
│  onKeyEvent → DeleteSelectionHandler               │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│              XtermManager (Riverpod)             │  (xterm_provider.dart)
│  · 终端 Session 创建与管理                       │
│  · 点击光标跳转分发                              │
│  · 粘贴板操作（复制/剪切/粘贴/全选/清除）        │
│  · 委托 PtyManager 管理 PTY 进程                 │
│  · 委托 CommandRunner 执行命令                   │
├─────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────┐   │
│  │             PtyManager                     │   │  (pty_manager.dart)
│  │  · PTY 进程生命周期                        │   │
│  │  · Shell 集成设置（Pwsh/Zsh/Bash）         │   │
│  │  · 输入输出转发                            │   │
│  │  · 光标移动请求（Ctrl+X,Ctrl+G）           │   │
│  │  · 崩溃自动重启                            │   │
│  └───────────────────────────────────────────┘   │
│  ┌───────────────────────────────────────────┐   │
│  │            CommandRunner                   │   │  (command_runner.dart)
│  │  · 命令执行与超时管理                      │   │
│  │  · OSC 633 标记解析                       │   │
│  │  · ANSI 清理与输出提取                    │   │
│  └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│               flutter_pty_new                    │
│  · PTY 进程创建                                  │
│  · 终端尺寸管理                                  │
│  · 输入输出流                                    │
└─────────────────────────────────────────────────┘
```

## 目录结构

```
lib/widgets/terminal/
├── xterm_widget.dart        # 终端 UI 组件，注册事件回调
├── xterm_provider.dart      # XtermManager (Riverpod) — 终端 Session 管理
├── xterm_provider.g.dart    # Riverpod 自动生成
├── pty_manager.dart         # PTY 进程生命周期、Shell 集成、崩溃恢复
├── command_runner.dart      # 命令执行与输出捕获
├── key_handler.dart         # 点击跳转光标 (MoveCursorHandler) + 删除选中 (DeleteSelectionHandler)
├── terminal_tabs.dart       # 终端标签页管理（多标签切换）
├── terminal_palette.dart    # 终端主题色板
└── shell_scripts.dart       # Shell 集成脚本模板（Pwsh/Zsh/Bash）
```

---

## 点击光标跳转功能

### 数据模型：`CellOffset`

`xterm2` 包中的 `CellOffset(x, y)` 表示终端缓冲区中的一个单元格位置（列, 行）。

```dart
// cell_offset.dart
class CellOffset {
  final int x;  // 列（0-based）
  final int y;  // 行（0-based，相对于整个缓冲区）
}
```

### 像素坐标 → 单元格坐标

`RenderTerminal.getCellOffset()` 将屏幕像素坐标转换为 `CellOffset`：

```dart
CellOffset getCellOffset(Offset offset) {
  final x = offset.dx - _padding.left;
  final y = offset.dy - _padding.top + _scrollOffset;
  final row = y ~/ _painter.cellSize.height;
  final col = x ~/ _painter.cellSize.width;
  return CellOffset(
    col.clamp(0, _terminal.viewWidth - 1),
    row.clamp(0, _terminal.buffer.lines.length - 1),
  );
}
```

### 完整事件链路

```
用户点击终端屏幕
  │
  ▼
TerminalView._onTapUp()                          (terminal_view.dart)
  │ renderTerminal.getCellOffset(localPosition)
  ▼
XtermTerminalWidget.onTapUp                       (xterm_widget.dart:73)
  │ XtermManager.handleTap(offset)
  ▼
MoveCursorHandler.handleTap()                     (key_handler.dart:102)
  │ MoveCursorHandler.createRequest() 计算 delta
  ▼
CursorMoveCallback → XtermManager._sendCursorMove  (xterm_provider.dart:159)
  │ PtyManager.tryCursorMove(delta) 通过 Ctrl+X Ctrl+G 发送？
  ├─ 是：Shell 行编辑器一次设置光标位置（Pwsh/Readline/ZLE）
  └─ 否：回退到 ANSI 方向键序列（\x1b[C / \x1b[D）
```

### MoveCursorHandler 算法

`MoveCursorHandler` 通过 `createRequest()` 计算光标需要移动的字符数：

```dart
CursorMoveRequest? createRequest(Terminal terminal, CellOffset offset) {
  final cursorX = terminal.buffer.cursorX;
  final cursorY = terminal.buffer.absoluteCursorY;
  final width = terminal.buffer.viewWidth;

  // 计算光标与目标在缓冲区中的绝对位置
  final cursorPosition = cursorY * width + cursorX;
  final targetPosition = offset.y * width + offset.x;
  if (cursorPosition == targetPosition) return null;

  // 遍历区间内的单元格，统计非空字符数
  int characterCount = 0;
  for (int y = startY; y <= endY; y++) {
    for (int x = startX; x < endX; x++) {
      if (line.getCodePoint(x) != 0) characterCount++;
    }
  }

  return CursorMoveRequest(movingRight ? characterCount : -characterCount);
}
```

算法要点：

- 普通字符的单元格 `codePoint != 0`，计为一个字符
- 汉字等宽字符占两个单元格，但续格 `codePoint == 0`，因此只计一次
- 空白占位单元格不计数
- 向右移动得到正偏移，向左移动得到负偏移

### 光标移动方式

`CursorMoveRequest` 包含 delta（正数向右，负数向左）以及 ANSI 回退序列：

```dart
class CursorMoveRequest {
  const CursorMoveRequest(this.delta);

  final int delta;

  String get fallbackInput {
    final sequence = delta > 0 ? '\x1b[C' : '\x1b[D';
    final buffer = StringBuffer();
    for (int i = 0; i < delta.abs(); i++) {
      buffer.write(sequence);
    }
    return buffer.toString();
  }
}
```

### 设计要点

1. **行编辑器级定位**：PowerShell/PSReadLine、Bash/Readline、Zsh/ZLE 通过 Shell 集成（`Ctrl+X,Ctrl+G`）一次更新内部光标，不产生逐字符移动过程
2. **兼容回退**：不支持 Shell 集成或子程序正在运行时仍发送 ANSI 左右方向键，避免私有快捷键干扰 Vim、less 等程序
3. **字符偏移**：跨行点击遍历 xterm 单元格并跳过宽字符续格，再由行编辑器限制在当前输入缓冲区范围内
4. **宽字符**：汉字等双单元格字符按一个光标步长处理；组合 emoji 的显示宽度仍取决于 Shell 与终端的 Unicode 实现
5. **可扩展性**：`MoveCursorHandler.handleTap()` 接受 `onCursorMove` 回调，可在不修改核心算法的情况下自定义移动行为

---

## 键盘事件处理

### DeleteSelectionHandler

当用户选中文本后按 Delete 或 Backspace：

1. `canHandle()` 匹配 `LogicalKeyboardKey.delete` 或 `LogicalKeyboardKey.backspace`
2. 获取当前选中的文本段 `controller.selection`
3. 遍历选中区域，统计非空字符数
4. 先将光标移动到选中区域的尾部（使用 `MoveCursorHandler.createRequest()` 计算偏移）
5. 发送对应次数的 Backspace 键删除选中字符

```dart
class DeleteSelectionHandler {
  bool canHandle(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace;

  bool handle(Terminal terminal, TerminalController controller) {
    final sel = controller.selection;
    if (sel == null) return false;
    // ... 遍历选中区域、移动光标、发送 Backspace
  }
}
```

### 注册方式

在 `xterm_widget.dart` 的 `onKeyEvent` 中直接使用，无需工厂：

```dart
final deleteHandler = useMemoized(() => DeleteSelectionHandler());

onKeyEvent: (node, event) {
  if (event is KeyDownEvent &&
      deleteHandler.canHandle(event.logicalKey)) {
    if (deleteHandler.handle(session.terminal, session.controller)) {
      return KeyEventResult.handled;
    }
  }
  return KeyEventResult.ignored;
},
```

---

## PTY 与 Shell 集成

### PTY 生命周期（PtyManager）

`PtyManager` 是一个独立类，由 `XtermManager` 创建并持有，负责 PTY 进程的完整生命周期：

| 阶段 | 方法 | 说明 |
|------|------|------|
| 创建 | `start()` | 解析 shell 路径，创建 PTY 进程 |
| 输入 | `terminal.onOutput` | 终端输出 → 写入 PTY（`pty.write()`） |
| 输出 | `pty.output.listen` | PTY 输出 → 写入终端（`terminal.write()`） |
| 调整尺寸 | `terminal.onResize` | 终端尺寸变化 → PTY resize |
| 光标移动 | `tryCursorMove(delta)` | 将偏移写入临时文件 → 发送 `Ctrl+X,Ctrl+G` |
| 崩溃恢复 | `_scheduleRestart()` | 5 秒内超过 3 次崩溃则暂停等待按键重试 |

```dart
// PtyManager 构造
_ptyManager = PtyManager(
  id: id,
  terminal: terminal,
  onOutput: _commandRunner!.feedOutput,
);

// 启动 PTY
_ptyManager?.start(shell: shell, args: args);

// 光标移动委托
bool tryCursorMove(int delta) {
  // 写入临时文件 → 发送 Ctrl+X,Ctrl+G
  File(path).writeAsStringSync('$delta');
  sendInput(_cursorMoveChord);  // \x18\x07
  return true;
}
```

### Shell 集成

为支持光标跳转和 `execute()` 命令执行功能，项目为不同 Shell 注入集成脚本：

| Shell | 机制 | 注入内容 |
|-------|------|----------|
| PowerShell | `-Command . 'script.ps1'` | 重写 `prompt` 函数，输出 OSC 633 序列；注册 `Ctrl+X,Ctrl+G` 读取光标偏移 |
| zsh | `ZDOTDIR` 临时目录 + `.zshrc` | `preexec`/`precmd` hook 输出 OSC 633 序列；`bindkey` 注册 `Ctrl+X,Ctrl+G` |
| bash | `--rcfile` 指定脚本 | `PROMPT_COMMAND` 输出 OSC 633 序列；`bind` 注册 `Ctrl+X,Ctrl+G` |

OSC 633 序列格式：
- `\x1b]633;C\x07` — 命令开始
- `\x1b]633;D;<exitCode>\x07` — 命令结束（含退出码）

### 光标移动请求（Ctrl+X, Ctrl+G）

Shell 集成脚本注册了 `Ctrl+X,Ctrl+G` 快捷键，当 PtyManager 需要移动光标时：

1. 将 delta 值写入临时文件（`agent-cursor-{id}.txt`）
2. 向 PTY 发送 `\x18\x07`（Ctrl+X, Ctrl+G）
3. Shell 的行编辑器（PSReadLine / Readline / ZLE）读取临时文件中的 delta
4. 一次更新内部光标位置，不产生逐字符移动

---

## 命令执行（CommandRunner）

`CommandRunner` 监听 PTY 输出流，通过 OSC 633 标记检测命令开始和结束边界。

### 执行流程

```
XtermManager.execute(command)
  │ CommandRunner.execute(command, sendInput, timeout)
  │  订阅 _outputController 流
  │  发送命令到 PTY
  ▼
等待 OSC 633 结束标记匹配
  │
  ├─ 匹配成功：提取命令输出，清理 ANSI，返回结果
  └─ 超时：抛出 TimeoutException
```

### 输出处理

```dart
Future<String> execute(String command, {
  required void Function(String text) sendInput,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final oscEnd = RegExp(r'\x1B\]633;D;-?\d+(?:\x07|\x1B\\)');
  // ... 订阅输出流，等待 OSC 633;D 标记 ...
  // 提取输出：从 633;C 到 633;D 之间的内容
  // 清理 ANSI 转义序列
  // 移除退格符（\x08）、回车符、Shell 提示符行
}
```

---

## 扩展指南

### 添加新的点击行为

`MoveCursorHandler.handleTap()` 接受 `onCursorMove` 回调，可在不修改核心算法的情况下自定义移动行为：

```dart
// 在 XtermManager 中
void handleTap(CellOffset offset) {
  MoveCursorHandler.handleTap(
    state.terminal,
    offset,
    onCursorMove: _sendCursorMove,
  );
}
```

若要添加全新的点击行为，可在 `xterm_widget.dart` 的 `onTapUp` 回调中扩展：

```dart
onTapUp: (details, offset) {
  ref.read(xtermManagerProvider(id).notifier).handleTap(offset);
  // 添加自定义点击逻辑
},
```

### 添加新的按键处理

在 `xterm_widget.dart` 的 `onKeyEvent` 中扩展：

```dart
onKeyEvent: (node, event) {
  if (event is KeyDownEvent) {
    // 自定义按键处理
    if (event.logicalKey == LogicalKeyboardKey.keyX) {
      // 处理逻辑
      return KeyEventResult.handled;
    }
    // 委托给 DeleteSelectionHandler
    if (deleteHandler.canHandle(event.logicalKey)) {
      if (deleteHandler.handle(session.terminal, session.controller)) {
        return KeyEventResult.handled;
      }
    }
  }
  return KeyEventResult.ignored;
},
```

---

## 关键文件索引

| 文件 | 关键行 | 内容 |
|------|--------|------|
| `lib/widgets/terminal/xterm_widget.dart` | 73-75 | `onTapUp` 回调 → `XtermManager.handleTap()` |
| `lib/widgets/terminal/xterm_widget.dart` | 64-71 | `onKeyEvent` → `DeleteSelectionHandler` |
| `lib/widgets/terminal/xterm_widget.dart` | 31-34 | `useEffect` 启动 PTY |
| `lib/widgets/terminal/xterm_provider.dart` | 35-64 | `XtermManager` 定义与 build 方法 |
| `lib/widgets/terminal/xterm_provider.dart` | 71-73 | `startPty()` 启动 PTY 进程 |
| `lib/widgets/terminal/xterm_provider.dart` | 81-86 | `handleTap()` 点击光标跳转 |
| `lib/widgets/terminal/xterm_provider.dart` | 90-98 | `execute()` 命令执行 |
| `lib/widgets/terminal/xterm_provider.dart` | 106-123 | `copySelection()` / `pasteText()` |
| `lib/widgets/terminal/xterm_provider.dart` | 126-138 | `selectAll()` / `clearTerminal()` |
| `lib/widgets/terminal/xterm_provider.dart` | 141-153 | `cutSelection()` / `deleteSelection()` |
| `lib/widgets/terminal/xterm_provider.dart` | 159-169 | `_sendCursorMove()` 光标移动回调 |
| `lib/widgets/terminal/pty_manager.dart` | 59-120 | `start()` PTY 进程完整启动流程 |
| `lib/widgets/terminal/pty_manager.dart` | 88-93 | `terminal.onOutput` → PTY 写入 |
| `lib/widgets/terminal/pty_manager.dart` | 95-97 | `terminal.onResize` → PTY resize |
| `lib/widgets/terminal/pty_manager.dart` | 99-112 | PTY 输出 → `terminal.write()` |
| `lib/widgets/terminal/pty_manager.dart` | 114-119 | 进程退出 → 崩溃恢复调度 |
| `lib/widgets/terminal/pty_manager.dart` | 128-143 | `tryCursorMove()` 光标集成移动 |
| `lib/widgets/terminal/pty_manager.dart` | 154-216 | Shell 集成设置（Pwsh/Zsh/Bash） |
| `lib/widgets/terminal/pty_manager.dart` | 244-269 | `_scheduleRestart()` 崩溃恢复 |
| `lib/widgets/terminal/pty_manager.dart` | 275-303 | `_trackUserInput()` / `_trackShellOutput()` |
| `lib/widgets/terminal/command_runner.dart` | 24-96 | `execute()` 命令执行与输出解析 |
| `lib/widgets/terminal/command_runner.dart` | 29 | `oscEnd` 正则匹配 `633;D` 结束标记 |
| `lib/widgets/terminal/key_handler.dart` | 6-53 | `DeleteSelectionHandler` 删除选中文本 |
| `lib/widgets/terminal/key_handler.dart` | 56-82 | `MoveCursorHandler.createRequest()` 偏移计算 |
| `lib/widgets/terminal/key_handler.dart` | 86-109 | `MoveCursorHandler.handle()` / `handleTap()` |
| `lib/widgets/terminal/key_handler.dart` | 113-128 | `CursorMoveRequest` 数据模型 |
| `lib/widgets/terminal/shell_scripts.dart` | 12-31 | PowerShell 集成脚本模板 |
| `lib/widgets/terminal/shell_scripts.dart` | 34-42 | `pwshScript()` 模板渲染 |
| `lib/widgets/terminal/shell_scripts.dart` | 44-67 | Zsh 集成脚本模板与渲染 |
| `lib/widgets/terminal/shell_scripts.dart` | 69-101 | Bash 集成脚本模板与渲染 |
| `lib/widgets/terminal/terminal_tabs.dart` | 17-115 | 多标签页管理 |
| `lib/widgets/terminal/terminal_palette.dart` | - | 终端主题色板定义 |
| `.../xterm2/terminal_view.dart` | 489-497 | `_onTapUp` 事件分发 |
| `.../xterm2/ui/render.dart` | 384-393 | `getCellOffset()` 坐标转换 |
| `.../xterm2/ui/render.dart` | 375-381 | `getOffset()` 单元格→像素 |
| `.../xterm2/ui/gesture/gesture_handler.dart` | 211-213 | `onSingleTapUp` |
| `.../xterm2/core/buffer/cell_offset.dart` | 1-55 | `CellOffset` 数据模型 |
| `.../xterm2/terminal.dart` | 507-537 | `keyInput()` 按键输出 |
