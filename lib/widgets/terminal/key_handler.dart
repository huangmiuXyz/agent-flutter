import 'package:flutter/services.dart';
import 'package:kterm/kterm.dart';

// ─── 按键处理器 ───────────────────────────────────────────────

abstract class KeyHandler {
  bool canHandle(LogicalKeyboardKey key);
  bool handle(Terminal terminal, TerminalController controller);
}

/// 选中删除：选中文本后按 Delete/Backspace，向 shell 发等量退格
class DeleteSelectionHandler implements KeyHandler {
  @override
  bool canHandle(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace;

  @override
  bool handle(Terminal terminal, TerminalController controller) {
    final sel = controller.selection;
    if (sel == null) return false;
    controller.clearSelection();

    final cursorY = terminal.buffer.absoluteCursorY;
    int count = 0;
    int tail = -1;
    for (final seg in sel.normalized.toSegments()) {
      if (seg.line != cursorY) continue;
      final start = seg.start ?? 0;
      final end = seg.end ?? terminal.buffer.viewWidth;
      final line = terminal.buffer.lines[seg.line];
      for (int i = start; i < end; i++) {
        if (line.getCodePoint(i) != 0) {
          count++;
          if (i + 1 > tail) tail = i + 1;
        }
      }
    }

    if (count <= 0 || tail <= 0) return true;

    final offset = tail - terminal.buffer.cursorX;
    if (offset > 0) {
      for (int i = 0; i < offset; i++) {
        terminal.keyInput(TerminalKey.arrowRight);
      }
    } else if (offset < 0) {
      for (int i = 0; i < -offset; i++) {
        terminal.keyInput(TerminalKey.arrowLeft);
      }
    }
    for (int i = 0; i < count; i++) {
      terminal.keyInput(TerminalKey.backspace);
    }
    return true;
  }
}

class KeyHandlerFactory {
  static final List<KeyHandler> _handlers = [
    DeleteSelectionHandler(),
  ];

  static KeyHandler? forKey(LogicalKeyboardKey key) {
    for (final h in _handlers) {
      if (h.canHandle(key)) return h;
    }
    return null;
  }
}

// ─── 点击处理器 ───────────────────────────────────────────────

abstract class TapHandler {
  void handle(Terminal terminal, CellOffset offset);
}

/// 点击移动光标：在 TUI（vim/less 等）中可跨行移动，在 shell点击光标所在行的某个位置，发左右箭头把光标移过去
/// 点击移动光标：用左右箭头跨行跳转（shell 多行输入时自动折行）
class MoveCursorHandler implements TapHandler {
  @override
  void handle(Terminal terminal, CellOffset offset) {
    final cursorX = terminal.buffer.cursorX;
    final cursorY = terminal.buffer.absoluteCursorY;
    final dy = offset.y - cursorY;
    final dx = offset.x - cursorX;

    if (dy == 0) {
      // 同行：直接左右
      if (dx > 0) {
        for (int i = 0; i < dx; i++) {
          terminal.keyInput(TerminalKey.arrowRight);
        }
      } else if (dx < 0) {
        for (int i = 0; i < -dx; i++) {
          terminal.keyInput(TerminalKey.arrowLeft);
        }
      }
      return;
    }

    // 跨行：先折行到目标行的开头，再左右调整
    final w = terminal.buffer.viewWidth;
    int arrows;
    TerminalKey key;

    if (dy < 0) {
      // 目标在上方：从当前列一直左键到折回目标行
      arrows = cursorX + 1;                       // 到行首 + 折到上一行
      for (int i = 0; i < -dy - 1; i++) {
        arrows += w + 1;                          // 再往上折 dy-1 行
      }
      arrows += w - offset.x;                     // 从行尾到目标列
      key = TerminalKey.arrowLeft;
    } else {
      // 目标在下方：从当前列一直右键到折回目标行
      arrows = w - cursorX;                       // 到行尾
      for (int i = 0; i < dy - 1; i++) {
        arrows += w + 1;                          // 再往下折 dy-1 行
      }
      arrows += offset.x + 1;                     // 从行首到目标列 + 1
      key = TerminalKey.arrowRight;
    }

    for (int i = 0; i < arrows; i++) {
      terminal.keyInput(key);
    }
  }
}

class TapHandlerFactory {
  static final List<TapHandler> _handlers = [
    MoveCursorHandler(),
  ];

  static void handleTap(Terminal terminal, CellOffset offset) {
    for (final h in _handlers) {
      h.handle(terminal, offset);
    }
  }
}
