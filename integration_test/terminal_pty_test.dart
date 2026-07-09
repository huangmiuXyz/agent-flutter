import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent/widgets/terminal/terminal_widget.dart';
import 'package:agent/widgets/terminal/provider.dart';

Future<String> waitForOutput(
  Stream<String> output,
  Pattern expect, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final completer = Completer<String>();
  final collected = StringBuffer();
  StreamSubscription<String>? sub;

  sub = output.listen((chunk) {
    collected.write(chunk);
    if (collected.toString().contains(expect)) {
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(collected.toString());
    }
  });

  return completer.future.timeout(timeout);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('terminal window shows shell prompt and responds to input', (tester) async {
    final container = ProviderContainer();
    addTearDown(() => container.dispose());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: TerminalWidget(id: 'integration_test'),
            ),
          ),
        ),
      ),
    );

    // Wait for TerminalView to lay out and PTY to start
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final tm = container.read(terminalManagerProvider('integration_test').notifier);

    // Send a command and verify output
    tm.sendInput('echo "hello_integration"\r');

    final output = await waitForOutput(tm.output, 'hello_integration');
    expect(output, contains('hello_integration'));
  });
}
