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
  │ TapHandlerFactory.handleTap(session.terminal, offset)
  ▼
MoveCursorHandler.handle(terminal, offset)        (key_handler.dart:72)
  │ 计算箭头按键次数，循环发送
  ▼
terminal.keyInput(TerminalKey.arrowLeft/Right)    (terminal.dart:507)
  │ 生成 ANSI 转义序列（←=\x1b[D, →=\x1b[C）
  ▼
terminal.onOutput → pty.write(bytes)              (xterm_provider.dart:112)
  │
  ▼
PTY → Shell 内部光标移动
```

### MoveCursorHandler 算法

由于终端光标只能通过左/右箭头一维移动，跨行跳转需要绕行策略：

#### 同行跳转（`dy == 0`）

```
  目标在右侧：发送 dx 次 → 键
  目标在左侧：发送 |dx| 次 ← 键
```

#### 向上跳转（`dy < 0`）

```
  从当前列左移到行首：             cursorX + 1     次 ←
  每向上穿越一行（行尾→行首绕行）：  w + 1           次 ←
  在目标行左移到目标列：             w - offset.x    次 ←
```

示例：光标在 (5, 3)，目标在 (2, 1)，viewWidth=80

```
  (5,3) → 左移6次到行首(0,3)
       → 左移81次到行尾(79,2) → 左移81次到行首(0,1)
       → 左移78次到(2,1)
  总计：6 + 81 + 78 = 165 次 ← 键
```

#### 向下跳转（`dy > 0`）

```
  从当前列右移到行尾：             w - cursorX      次 →
  每向下穿越一行（行首→行尾绕行）：  w + 1            次 →
  在目标行右移到目标列：             offset.x + 1     次 →
```

### 设计要点

1. **纯键盘模拟**：不依赖应用的鼠标支持模式，兼容 vim、nano、less 等不支持鼠标输入的应用程序
2. **一维移动限制**：终端协议层只暴露左/右箭头，垂直移动通过行首/行尾绕行实现
3. **像素精度**：`getCellOffset()` 基于固定宽度字符布局计算，不感知变宽字符（如 emoji）
4. **可扩展性**：`TapHandlerFactory` 使用列表注册模式，新增行为只需添加 `TapHandler` 实现

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
| `lib/widgets/terminal/key_handler.dart` | 72-117 | `MoveCursorHandler` 算法实现 |
| `lib/widgets/terminal/key_handler.dart` | 119-128 | `TapHandlerFactory` 工厂 |
| `lib/widgets/terminal/key_handler.dart` | 9-53 | `DeleteSelectionHandler` |
| `lib/widgets/terminal/key_handler.dart` | 55-66 | `KeyHandlerFactory` 工厂 |
| `lib/widgets/terminal/xterm_provider.dart` | 48-381 | `XtermManager` PTY 管理 |
| `lib/widgets/terminal/xterm_provider.dart` | 112-117 | 终端输出 → PTY 写入 |
| `lib/widgets/terminal/xterm_provider.dart` | 119-121 | 终端 resize → PTY |
| `lib/widgets/terminal/xterm_provider.dart` | 123-135 | PTY 输出 → 终端写入 |
| `.../xterm2/terminal_view.dart` | 489-497 | `_onTapUp` 事件分发 |
| `.../xterm2/ui/render.dart` | 384-393 | `getCellOffset()` 坐标转换 |
| `.../xterm2/ui/render.dart` | 375-381 | `getOffset()` 单元格→像素 |
| `.../xterm2/ui/gesture/gesture_handler.dart` | 211-213 | `onSingleTapUp` |
| `.../xterm2/core/buffer/cell_offset.dart` | 1-55 | `CellOffset` 数据模型 |
| `.../xterm2/terminal.dart` | 507-537 | `keyInput()` 按键输出 |
