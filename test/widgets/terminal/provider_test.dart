import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent/widgets/terminal/provider.dart';

void main() {
  group('TerminalManager.execute', () {
    const testId = 'test';

    late ProviderContainer container;
    late TerminalManager tm;

    setUp(() {
      container = ProviderContainer();
      tm = container.read(terminalManagerProvider(testId).notifier);
    });

    tearDown(() => container.dispose());

    test('returns output when OSC 633 marker is detected', () async {
      final result = tm.execute('echo hello', timeout: const Duration(seconds: 1));

      tm.injectOutput('hello\r\n');
      tm.injectOutput('\x1b]633;D;0\x1b\\C:\\path>');

      expect(await result, contains('hello'));
    });

    test('throws TimeoutException when marker never arrives', () async {
      expect(
        tm.execute('sleep 10', timeout: const Duration(milliseconds: 100)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('completes on first marker in stream', () async {
      final result = tm.execute('cmd1', timeout: const Duration(seconds: 1));

      tm.injectOutput('output1\r\n');
      tm.injectOutput('\x1b]633;D;0\x1b\\');
      tm.injectOutput('output2\r\n');
      tm.injectOutput('\x1b]633;D;0\x1b\\');

      final output = await result;
      expect(output, contains('output1'));
      expect(output, isNot(contains('output2')));
    });

    test('multiple execute calls share the same output stream', () async {
      final result1 = tm.execute('cmd1', timeout: const Duration(seconds: 1));
      final result2 = tm.execute('cmd2', timeout: const Duration(seconds: 1));

      tm.injectOutput('shared_output\r\n');
      tm.injectOutput('\x1b]633;D;0\x1b\\');

      final out1 = await result1;
      final out2 = await result2;
      expect(out1, contains('shared_output'));
      expect(out2, contains('shared_output'));
    });

    test('different IDs have independent state', () async {
      final tm1 = container.read(terminalManagerProvider('tab1').notifier);
      final tm2 = container.read(terminalManagerProvider('tab2').notifier);

      final r1 = tm1.execute('cmd1', timeout: const Duration(seconds: 1));
      final r2 = tm2.execute('cmd2', timeout: const Duration(seconds: 1));

      tm1.injectOutput('tab1_output\r\n');
      tm1.injectOutput('\x1b]633;D;0\x1b\\');
      tm2.injectOutput('tab2_output\r\n');
      tm2.injectOutput('\x1b]633;D;0\x1b\\');

      expect(await r1, contains('tab1_output'));
      expect(await r2, contains('tab2_output'));
    });
  });
}
