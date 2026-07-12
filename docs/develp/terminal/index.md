# 内置终端开发指南

## 概述

该项目基于 `xterm2` 包实现了内置终端模拟器。终端通过 `flutter_pty_new` 与系统 Shell（PowerShell/zsh/bash）通信，并实现了点击文字跳转光标、文本选择与删除等交互功能。

---

## 架构总览

```
┌─────────────────────────────────────────────────┐
│                   XtermTerminalWidget            │  (xterm_widget.dart)
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
│  onTapUp → TapHandlerFactory.handleTap             │
│  onKeyEvent → KeyHandlerFactory.forKey             │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│                XtermManager (Riverpod)           │  (xterm_provider.dart)
│  · PTY 进程管理                                  │
│  · Shell 集成配置                                │
│  · 输入输出转发                                  │
│  · 崩溃自动重启                                  │
│  · execute() 命令执行                            │
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
├── xterm_provider.dart      # 终端状态管理，PTY 生命周期
├── xterm_provider.g.dart    # Riverpod 自动生成
├── key_handler.dart         # 点击跳转 + 键盘事件处理
├── terminal_tabs.dart       # 终端标签页管理
└── terminal_palette.dart    # 终端主题色板
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
TerminalView._onTapUp()                          (terminal_view.dart:489)
  │ renderTerminal.getCellOffset(localPosition)
  ▼
XtermTerminalWidget.onTapUp                       (xterm_widget.dart:71)
  │ XtermManager.handleTap(offset)
  ▼
TapHandlerFactory / MoveCursorHandler
  │ 计算目标相对偏移
  ▼
Shell 集成可用且当前位于提示符？
  ├─ 是：写入偏移请求，发送 Ctrl+X Ctrl+G
  │      PowerShell/Bash/Zsh 行编辑器一次设置光标位置
  └─ 否：生成重复的左右方向键序列作为兼容回退
```

### MoveCursorHandler 算法

点击位置先按二维终端坐标确定移动区间，再遍历区间内的 xterm 单元格：

- 普通字符的单元格 `codePoint != 0`，计为一个字符
- 汉字等宽字符占两个单元格，但续格 `codePoint == 0`，因此只计一次
- 空白占位单元格不计数
- 向右移动得到正偏移，向左移动得到负偏移

Shell 集成可用时，行编辑器一次应用字符偏移；否则发送相同数量的左右方向键作为兼容回退。点击宽字符的左半格会定位到字符前，点击右半格会定位到字符后。

### 设计要点

1. **行编辑器级定位**：PowerShell/PSReadLine、Bash/Readline、Zsh/ZLE 通过 Shell 集成一次更新内部光标，不产生逐字符移动过程
2. **兼容回退**：不支持 Shell 集成或子程序正在运行时仍发送左右方向键，避免私有快捷键干扰 Vim、less 等程序
3. **字符偏移**：跨行点击遍历 xterm 单元格并跳过宽字符续格，再由行编辑器限制在当前输入缓冲区范围内
4. **宽字符**：汉字等双单元格字符按一个光标步长处理；组合 emoji 的显示宽度仍取决于 Shell 与终端的 Unicode 实现
5. **可扩展性**：`TapHandlerFactory` 使用列表注册模式，新增行为只需添加 `TapHandler` 实现

---

## 键盘事件处理

### KeyHandler 工厂模式

```dart
abstract class KeyHandler {
  bool canHandle(LogicalKeyboardKey key);
  bool handle(Terminal terminal, TerminalController controller);
}

class KeyHandlerFactory {
  static final List<KeyHandler> _handlers = [
    DeleteSelectionHandler(),
  ];
}
```

### 删除选中文本（DeleteSelectionHandler）

当用户选中文本后按 Delete 或 Backspace：

1. 获取当前选中的文本段
2. 计算选中区域在光标所在行的字符数和结束位置
3. 先将光标移动到选中区域的尾部
4. 发送对应次数的 Backspace 键删除选中字符

---

## PTY 与 Shell 集成

### PTY 生命周期（XtermManager）

| 阶段 | 方法 | 说明 |
|---|---|---|
| 创建 | `startPty()` | 解析 shell 路径，创建 PTY 进程 |
| 输入 | `terminal.onOutput` | 终端输出 → 写入 PTY |
| 输出 | `pty.output.listen` | PTY 输出 → 写入终端 |
| 调整尺寸 | `terminal.onResize` | 终端尺寸变化 → PTY resize |
| 崩溃恢复 | `_scheduleRestart()` | 5 秒内超过 3 次崩溃则暂停等待按键重试 |

### Shell 集成

为支持 `execute()` 命令执行功能，项目为不同 Shell 注入集成脚本：

| Shell | 机制 | 注入内容 |
|---|---|---|
| PowerShell | `-Command . 'script.ps1'` | 重写 `prompt` 函数，输出 OSC 633 序列标记命令边界 |
| zsh | `ZDOTDIR` 临时目录 + `.zshrc` | `preexec`/`precmd` hook 输出 OSC 633 序列 |
| bash | `--rcfile` 指定脚本 | `PROMPT_COMMAND` 输出 OSC 633 序列 |

OSC 633 序列格式：
- `\x1b]633;C\x07` — 命令开始
- `\x1b]633;D;<exitCode>\x07` — 命令结束（含退出码）

---

## 扩展指南

### 添加新的点击行为

```dart
class MyTapHandler implements TapHandler {
  @override
  void handle(Terminal terminal, CellOffset offset) {
    // 实现自定义点击逻辑
  }
}

// 在 TapHandlerFactory._handlers 中注册
class TapHandlerFactory {
  static final List<TapHandler> _handlers = [
    MoveCursorHandler(),
    MyTapHandler(),  // 新增
  ];
}
```

### 添加新的按键处理

```dart
class MyKeyHandler implements KeyHandler {
  @override
  bool canHandle(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.keyX;

  @override
  bool handle(Terminal terminal, TerminalController controller) {
    // 返回 true 表示已处理
    return true;
  }
}

// 在 KeyHandlerFactory._handlers 中注册
class KeyHandlerFactory {
  static final List<KeyHandler> _handlers = [
    DeleteSelectionHandler(),
    MyKeyHandler(),
  ];
}
```

---

## 关键文件索引

| 文件 | 关键行 | 内容 |
|---|---|---|
| `lib/widgets/terminal/xterm_widget.dart` | 71-73 | `onTapUp` 回调注册 |
| `lib/widgets/terminal/xterm_widget.dart` | 60-69 | `onKeyEvent` 回调注册 |
| `lib/widgets/terminal/key_handler.dart` | 68-119 | 光标偏移请求与 `MoveCursorHandler` |
| `lib/widgets/terminal/key_handler.dart` | 121-135 | `TapHandlerFactory` 工厂 |
| `lib/widgets/terminal/key_handler.dart` | 9-53 | `DeleteSelectionHandler` |
| `lib/widgets/terminal/key_handler.dart` | 55-66 | `KeyHandlerFactory` 工厂 |
| `lib/widgets/terminal/xterm_provider.dart` | 50-473 | `XtermManager` PTY 与 Shell 集成管理 |
| `lib/widgets/terminal/xterm_provider.dart` | 181-203 | 点击光标请求分发 |
| `lib/widgets/terminal/xterm_provider.dart` | 115-120 | 终端输出 → PTY 写入 |
| `lib/widgets/terminal/xterm_provider.dart` | 122-124 | 终端 resize → PTY |
| `lib/widgets/terminal/xterm_provider.dart` | 126-138 | PTY 输出 → 终端写入 |
| `.../xterm2/terminal_view.dart` | 489-497 | `_onTapUp` 事件分发 |
| `.../xterm2/ui/render.dart` | 384-393 | `getCellOffset()` 坐标转换 |
| `.../xterm2/ui/render.dart` | 375-381 | `getOffset()` 单元格→像素 |
| `.../xterm2/ui/gesture/gesture_handler.dart` | 211-213 | `onSingleTapUp` |
| `.../xterm2/core/buffer/cell_offset.dart` | 1-55 | `CellOffset` 数据模型 |
| `.../xterm2/terminal.dart` | 507-537 | `keyInput()` 按键输出 |
