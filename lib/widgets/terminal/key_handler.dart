import 'package:flutter/services.dart';
import 'package:xterm2/xterm.dart';

abstract class KeyHandler {
  bool canHandle(LogicalKeyboardKey key);
  bool handle(Terminal terminal, TerminalController controller);
}

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

abstract class TapHandler {
  void handle(Terminal terminal, CellOffset offset);
}

class MoveCursorHandler implements TapHandler {
  @override
  void handle(Terminal terminal, CellOffset offset) {
    final cursorX = terminal.buffer.cursorX;
    final cursorY = terminal.buffer.absoluteCursorY;
    final dy = offset.y - cursorY;
    final dx = offset.x - cursorX;

    if (dy == 0) {
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

    final w = terminal.buffer.viewWidth;
    int arrows;
    TerminalKey key;

    if (dy < 0) {
      arrows = cursorX + 1;
      for (int i = 0; i < -dy - 1; i++) {
        arrows += w + 1;
      }
      arrows += w - offset.x;
      key = TerminalKey.arrowLeft;
    } else {
      arrows = w - cursorX;
      for (int i = 0; i < dy - 1; i++) {
        arrows += w + 1;
      }
      arrows += offset.x + 1;
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
