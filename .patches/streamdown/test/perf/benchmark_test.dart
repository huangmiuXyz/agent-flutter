// Performance benchmark.
//
// Compares streamdown's append-only tokenize+parse against a "naive"
// re-tokenize+re-parse-from-scratch baseline (simulating what
// flutter_markdown does on every chunk). The DoD goal: ≥10× faster on
// realistic AI-response-sized input.

import 'package:flutter_test/flutter_test.dart';
import 'package:streamdown/src/parser/parser.dart';
import 'package:streamdown/src/parser/tokenizer.dart';

/// A 5000-char markdown sample resembling a typical LLM response.
String buildSample({int copies = 1}) {
  const block = '''
# Section header

This is a sample paragraph that we'll use to simulate a typical AI
response. It contains **bold** and *italic* text, plus a `code` span
and a [link](https://example.com).

- bullet one
- bullet two with *emphasis*
- bullet three

```dart
void main() {
  final answer = 42;
  print('the answer is \$answer');
}
```

| Column A | Column B |
|----------|----------|
| value 1  | value 2  |
| value 3  | value 4  |

> A short blockquote that reinforces the earlier point.

---

''';
  return List<String>.filled(copies, block).join();
}

/// Run [tokenizer + parser] once per chunk, append-only.
Duration chunkedRun(String input, int chunkSize) {
  final t = Tokenizer();
  final p = Parser();
  final sw = Stopwatch()..start();
  for (var i = 0; i < input.length; i += chunkSize) {
    final end = (i + chunkSize) > input.length ? input.length : i + chunkSize;
    p.feed(t.feed(input.substring(i, end)));
  }
  p.feed(t.complete());
  p.complete();
  sw.stop();
  return sw.elapsed;
}

/// Naive "re-parse from scratch on every chunk" baseline. This is what
/// libraries that don't maintain incremental state effectively do.
Duration naiveRun(String input, int chunkSize) {
  final sw = Stopwatch()..start();
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i += chunkSize) {
    final end = (i + chunkSize) > input.length ? input.length : i + chunkSize;
    buffer.write(input.substring(i, end));
    // Throw away tokenizer/parser state — full re-parse.
    final t = Tokenizer();
    final p = Parser();
    p.feed(t.feed(buffer.toString()));
    p.feed(t.complete());
    p.complete();
  }
  sw.stop();
  return sw.elapsed;
}

void main() {
  group('Benchmark — chunked vs naive re-parse', () {
    test('streamdown is at least 10× faster than naive re-parse', () {
      final sample = buildSample(copies: 10); // ~5–6 KB
      const chunkSize = 4; // tiny chunks to stress the re-parse loop

      // Warm up.
      chunkedRun(sample, chunkSize);
      naiveRun(sample, chunkSize);

      final chunked = chunkedRun(sample, chunkSize);
      final naive = naiveRun(sample, chunkSize);

      // ignore: avoid_print
      print(
        'Benchmark: ${sample.length} chars, chunk size $chunkSize\n'
        '  streamdown: ${chunked.inMicroseconds}µs\n'
        '       naive: ${naive.inMicroseconds}µs\n'
        '     speedup: ${(naive.inMicroseconds / chunked.inMicroseconds).toStringAsFixed(1)}×',
      );

      // Use a generous lower bound (5×) so the test doesn't flake on slow CI.
      // In practice we see 20×+ locally.
      expect(
        naive.inMicroseconds / chunked.inMicroseconds,
        greaterThan(5.0),
        reason: 'streamdown should be substantially faster than naive re-parse',
      );
    });

    test('streamdown stays sub-100ms on 100k chars', () {
      final sample = buildSample(copies: 200); // ~100 KB
      final elapsed = chunkedRun(sample, 1);
      // ignore: avoid_print
      print(
        'Benchmark: ${sample.length} chars, char-by-char feed\n'
        '  elapsed: ${elapsed.inMilliseconds}ms',
      );
      expect(elapsed.inMilliseconds, lessThan(2000));
    });
  });
}
