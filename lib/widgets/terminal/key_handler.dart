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
          final characterEnd = i + line.getWidth(i);
          if (characterEnd > tail) tail = characterEnd;
        }
      }
    }

    if (count <= 0 || tail <= 0) return true;

    final cursorX = terminal.buffer.cursorX;
    final line = terminal.buffer.lines[cursorY];
    final start = cursorX < tail ? cursorX : tail;
    final end = cursorX < tail ? tail : cursorX;
    int cursorSteps = 0;
    for (int i = start; i < end; i++) {
      if (line.getCodePoint(i) != 0) cursorSteps++;
    }

    final movingRight = tail > cursorX;
    for (int i = 0; i < cursorSteps; i++) {
      terminal.keyInput(
        movingRight ? TerminalKey.arrowRight : TerminalKey.arrowLeft,
      );
    }
    for (int i = 0; i < count; i++) {
      terminal.keyInput(TerminalKey.backspace);
    }
    return true;
  }
}

class KeyHandlerFactory {
  static final List<KeyHandler> _handlers = [DeleteSelectionHandler()];

  static KeyHandler? forKey(LogicalKeyboardKey key) {
    for (final h in _handlers) {
      if (h.canHandle(key)) return h;
    }
    return null;
  }
}

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

typedef CursorMoveCallback = void Function(CursorMoveRequest request);

abstract class TapHandler {
  void handle(
    Terminal terminal,
    CellOffset offset, {
    CursorMoveCallback? onCursorMove,
  });
}

class MoveCursorHandler implements TapHandler {
  CursorMoveRequest? createRequest(Terminal terminal, CellOffset offset) {
    final cursorX = terminal.buffer.cursorX;
    final cursorY = terminal.buffer.absoluteCursorY;
    final width = terminal.buffer.viewWidth;
    final cursorPosition = cursorY * width + cursorX;
    final targetPosition = offset.y * width + offset.x;
    if (cursorPosition == targetPosition) return null;

    final movingRight = targetPosition > cursorPosition;
    final startY = movingRight ? cursorY : offset.y;
    final endY = movingRight ? offset.y : cursorY;
    int characterCount = 0;

    for (int y = startY; y <= endY; y++) {
      final startX = y == startY ? (movingRight ? cursorX : offset.x) : 0;
      final endX = y == endY ? (movingRight ? offset.x : cursorX) : width;
      final line = terminal.buffer.lines[y];
      for (int x = startX; x < endX; x++) {
        if (line.getCodePoint(x) != 0) characterCount++;
      }
    }

    if (characterCount == 0) return null;
    return CursorMoveRequest(movingRight ? characterCount : -characterCount);
  }

  @override
  void handle(
    Terminal terminal,
    CellOffset offset, {
    CursorMoveCallback? onCursorMove,
  }) {
    final request = createRequest(terminal, offset);
    if (request == null) return;

    if (onCursorMove != null) {
      onCursorMove(request);
    } else {
      terminal.onOutput?.call(request.fallbackInput);
    }
  }
}

class TapHandlerFactory {
  static final List<TapHandler> _handlers = [MoveCursorHandler()];

  static void handleTap(
    Terminal terminal,
    CellOffset offset, {
    CursorMoveCallback? onCursorMove,
  }) {
    for (final handler in _handlers) {
      handler.handle(terminal, offset, onCursorMove: onCursorMove);
    }
  }
}
