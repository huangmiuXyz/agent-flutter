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

    final buffer = terminal.buffer;
    final cursor = CellOffset(buffer.cursorX, buffer.absoluteCursorY);
    final plan = _buildPlan(buffer, sel.normalized, cursor);
    controller.clearSelection();
    if (plan == null) return true;

    if (plan.end.isBeforeOrSame(cursor)) {
      // The selection is wholly to the left of the cursor. Move to its end
      // first so the intervening, unselected text is not removed.
      _sendRepeated(
        terminal,
        TerminalKey.arrowLeft,
        _countCharactersBetween(buffer, plan.end, cursor),
      );
      _sendRepeated(terminal, TerminalKey.backspace, plan.leftCount);
    } else if (plan.start.isAfterOrSame(cursor)) {
      // The selection is wholly to the right of the cursor. Move to its start
      // before using Delete.
      _sendRepeated(
        terminal,
        TerminalKey.arrowRight,
        _countCharactersBetween(buffer, cursor, plan.start),
      );
      _sendRepeated(terminal, TerminalKey.delete, plan.rightCount);
    } else {
      // The selection crosses the cursor. Delete the right side first; any
      // terminal padding past the real shell buffer is safely clamped there.
      _sendRepeated(terminal, TerminalKey.delete, plan.rightCount);
      _sendRepeated(terminal, TerminalKey.backspace, plan.leftCount);
    }
    return true;
  }

  _SelectionDeletePlan? _buildPlan(
    Buffer buffer,
    BufferRange selection,
    CellOffset cursor,
  ) {
    final firstEditableLine = _wrappedLineStart(buffer, cursor.y);
    final lastEditableLine = _wrappedLineEnd(buffer, cursor.y);
    final tokens = <_SelectedToken>[];

    for (final segment in selection.toSegments()) {
      if (segment.line < firstEditableLine ||
          segment.line > lastEditableLine ||
          segment.line < 0 ||
          segment.line >= buffer.height) {
        continue;
      }

      final line = buffer.lines[segment.line];
      var start = (segment.start ?? 0).clamp(0, buffer.viewWidth);
      var end = (segment.end ?? buffer.viewWidth).clamp(
        start,
        buffer.viewWidth,
      );

      // Mouse selection normally snaps wide characters already. Normalize the
      // endpoints as well because callers can construct ranges directly.
      if (start > 0 &&
          start < buffer.viewWidth &&
          line.getWidth(start) == 0 &&
          line.getWidth(start - 1) == 2) {
        start--;
      }
      if (end > 0 &&
          end < buffer.viewWidth &&
          line.getWidth(end) == 0 &&
          line.getWidth(end - 1) == 2) {
        end++;
      }

      for (int x = start; x < end; x++) {
        // A zero code point is either an empty cell or the continuation cell
        // of a wide character. Neither represents another edit operation.
        if (line.getCodePoint(x) == 0) continue;

        final width = line.getWidth(x);
        final tokenEnd = CellOffset(
          (x + (width > 0 ? width : 1)).clamp(0, buffer.viewWidth),
          segment.line,
        );
        tokens.add(
          _SelectedToken(
            start: CellOffset(x, segment.line),
            end: tokenEnd,
            codePoint: line.getCodePoint(x),
          ),
        );
      }
    }

    // A terminal may leave explicit spaces behind while repainting a shorter
    // command line. If the selected suffix is only whitespace to the right of
    // the shell cursor, it is padding rather than editable input. Trim that
    // suffix so Ctrl+X cannot turn it into extra deletion operations.
    while (tokens.isNotEmpty &&
        tokens.last.start.isAfterOrSame(cursor) &&
        _isWhitespace(tokens.last.codePoint)) {
      tokens.removeLast();
    }

    if (tokens.isEmpty) return null;

    var leftCount = 0;
    var rightCount = 0;
    for (final token in tokens) {
      if (token.end.isBeforeOrSame(cursor)) {
        leftCount++;
      } else if (token.start.isAfterOrSame(cursor)) {
        rightCount++;
      } else if (token.start.isBefore(cursor)) {
        // A cursor should normally never split a wide character, but treat
        // this case as left-sided rather than risking a right-side delete.
        leftCount++;
      } else {
        rightCount++;
      }
    }

    return _SelectionDeletePlan(
      start: tokens.first.start,
      end: tokens.last.end,
      leftCount: leftCount,
      rightCount: rightCount,
    );
  }

  bool _isWhitespace(int codePoint) =>
      String.fromCharCode(codePoint).trim().isEmpty;

  void _sendRepeated(Terminal terminal, TerminalKey key, int count) {
    for (var i = 0; i < count; i++) {
      terminal.keyInput(key);
    }
  }

  int _countCharactersBetween(Buffer buffer, CellOffset start, CellOffset end) {
    if (end.isBeforeOrSame(start)) return 0;

    var count = 0;
    for (var lineIndex = start.y; lineIndex <= end.y; lineIndex++) {
      if (lineIndex < 0 || lineIndex >= buffer.height) continue;
      final line = buffer.lines[lineIndex];
      final lineStart = lineIndex == start.y ? start.x : 0;
      final lineEnd = lineIndex == end.y ? end.x : buffer.viewWidth;
      final from = lineStart.clamp(0, buffer.viewWidth);
      final to = lineEnd.clamp(from, buffer.viewWidth);
      for (var x = from; x < to; x++) {
        if (line.getCodePoint(x) != 0) count++;
      }
    }
    return count;
  }

  int _wrappedLineStart(Buffer buffer, int line) {
    var first = line;
    while (first > 0 && buffer.lines[first].isWrapped) {
      first--;
    }
    return first;
  }

  int _wrappedLineEnd(Buffer buffer, int line) {
    var last = line;
    while (last + 1 < buffer.height && buffer.lines[last + 1].isWrapped) {
      last++;
    }
    return last;
  }
}

class _SelectedToken {
  const _SelectedToken({
    required this.start,
    required this.end,
    required this.codePoint,
  });

  final CellOffset start;
  final CellOffset end;
  final int codePoint;
}

class _SelectionDeletePlan {
  const _SelectionDeletePlan({
    required this.start,
    required this.end,
    required this.leftCount,
    required this.rightCount,
  });

  final CellOffset start;
  final CellOffset end;
  final int leftCount;
  final int rightCount;
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
