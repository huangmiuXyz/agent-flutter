import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

import 'package:agent/widgets/terminal/key_handler.dart';

void main() {
  group('DeleteSelectionHandler', () {
    test('moves by characters when deleting a wide-character selection', () {
      final terminal = Terminal();
      final controller = TerminalController();
      final output = <String>[];
      terminal.onOutput = output.add;
      terminal.write('a中b');
      final cursorY = terminal.buffer.absoluteCursorY;
      controller.setSelection(
        terminal.buffer.createAnchor(1, cursorY),
        terminal.buffer.createAnchor(3, cursorY),
      );

      final handled = DeleteSelectionHandler().handle(terminal, controller);

      expect(handled, isTrue);
      expect(controller.selection, isNull);
      expect(output, ['\x1b[D', '\x7f']);
    });
  });

  group('MoveCursorHandler', () {
    test('counts a wide character as one cursor step', () {
      final terminal = Terminal();
      terminal.write('a中b');
      final cursorY = terminal.buffer.absoluteCursorY;
      final handler = MoveCursorHandler();

      expect(terminal.buffer.cursorX, 4);
      expect(
        handler.createRequest(terminal, CellOffset(1, cursorY))?.delta,
        -2,
      );
      expect(
        handler.createRequest(terminal, CellOffset(2, cursorY))?.delta,
        -1,
      );
    });

    test('snaps the second cell of a wide character after the character', () {
      final terminal = Terminal();
      terminal.write('a中b\x1b[4D');
      final cursorY = terminal.buffer.absoluteCursorY;
      final handler = MoveCursorHandler();

      expect(terminal.buffer.cursorX, 0);
      expect(handler.createRequest(terminal, CellOffset(1, cursorY))?.delta, 1);
      expect(handler.createRequest(terminal, CellOffset(2, cursorY))?.delta, 2);
    });
  });
}
