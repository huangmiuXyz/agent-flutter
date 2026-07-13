import 'package:flutter/services.dart';
import 'package:xterm2/xterm.dart';

/// Handles Delete / Backspace when a selection is active:
/// removes the selected characters and moves the cursor accordingly.
class DeleteSelectionHandler {
  bool canHandle(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace;

  bool handle(Terminal terminal, TerminalController controller) {
    final sel = controller.selection;
    if (sel == null) return false;
    controller.clearSelection();

    final selection = sel.normalized;
    final buffer = terminal.buffer;

    int count = 0;
    CellOffset? selectionEnd;
    for (final segment in selection.toSegments()) {
      if (segment.line < 0 || segment.line >= buffer.height) continue;
      final line = buffer.lines[segment.line];
      final start = (segment.start ?? 0).clamp(0, buffer.viewWidth);
      final end = (segment.end ?? buffer.viewWidth).clamp(
        start,
        buffer.viewWidth,
      );
      for (int x = start; x < end; x++) {
        if (line.getCodePoint(x) != 0) count++;
      }
      selectionEnd = CellOffset(end, segment.line);
    }

    if (count <= 0 || selectionEnd == null) return true;

    final moveRequest = MoveCursorHandler().createRequest(
      terminal,
      selectionEnd,
    );
    if (moveRequest != null) {
      final key = moveRequest.delta > 0
          ? TerminalKey.arrowRight
          : TerminalKey.arrowLeft;
      for (int i = 0; i < moveRequest.delta.abs(); i++) {
        terminal.keyInput(key);
      }
    }
    for (int i = 0; i < count; i++) {
      terminal.keyInput(TerminalKey.backspace);
    }
    return true;
  }
}

/// Processes a tap on the terminal to move the cursor.
class MoveCursorHandler {
  /// Calculates the number of characters between the cursor and [offset].
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

  /// Moves the cursor by the computed delta.
  /// Calls [onCursorMove] if provided, otherwise sends ANSI escape sequences.
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

  /// Direct convenience: compute and move in one step with a callback.
  static void handleTap(
    Terminal terminal,
    CellOffset offset, {
    CursorMoveCallback? onCursorMove,
  }) {
    final handler = MoveCursorHandler();
    handler.handle(terminal, offset, onCursorMove: onCursorMove);
  }
}

/// Describes how many cells to move the cursor (positive = right).
class CursorMoveRequest {
  const CursorMoveRequest(this.delta);

  /// Signed delta: positive moves right, negative moves left.
  final int delta;

  /// ANSI escape sequence fallback.
  String get fallbackInput {
    final sequence = delta > 0 ? '\x1b[C' : '\x1b[D';
    final buffer = StringBuffer();
    for (int i = 0; i < delta.abs(); i++) {
      buffer.write(sequence);
    }
    return buffer.toString();
  }
}

/// Callback type for cursor movement.
typedef CursorMoveCallback = void Function(CursorMoveRequest request);
