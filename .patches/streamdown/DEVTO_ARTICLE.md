---
title: "The append-only AST trick that makes Flutter AI chat actually smooth"
published: false
description: How I built a flicker-free streaming markdown renderer for Flutter — 188× faster than flutter_markdown on chunked LLM output.
tags: flutter, dart, ai, opensource
canonical_url: https://github.com/jayu1023/streamdown
cover_image: https://raw.githubusercontent.com/jayu1023/streamdown/main/example/screenshots/split_screen_demo.gif
---

> TL;DR — `flutter_markdown` re-parses the entire response string on every streamed token. The fix is an append-only AST with monotonic node IDs used as Flutter widget keys. I packaged it as [`streamdown`](https://pub.dev/packages/streamdown) — a drop-in replacement that's **188× faster** on chunked input and produces zero visible flicker. Live on pub.dev today.

![streamdown vs flutter_markdown — split screen demo](https://raw.githubusercontent.com/jayu1023/streamdown/main/example/screenshots/split_screen_demo.gif)

---

## The problem

Every ChatGPT-style Flutter app I built had the same broken-feeling moment: code blocks flashing unstyled → styled → unstyled, tables jittering as new cells arrive, scroll position breaking, and the cursor jumping around like the UI is fighting itself.

The root cause is one line, repeated thousands of times during a single streamed response:

```dart
StreamBuilder<String>(
  stream: openai.responseStream,
  builder: (_, snap) => Markdown(data: snap.data ?? ''),
)
```

`flutter_markdown` does exactly what its API promises — it takes a complete string and renders it. The problem is that every new chunk produces a new `data` value, and the entire string gets re-tokenized, re-parsed, and re-rendered from scratch. That O(n²) work is invisible on a 200-char response; on a 5KB code-heavy answer it's the source of every visible glitch.

You can confirm this in five minutes: feed an OpenAI completion into `flutter_markdown` with `chunk_size=1` and watch a syntax-highlighted code block strobe like it's having a seizure.

## The three tricks (and why all three are needed)

Fixing this needs three changes that have to land together — fixing only one or two doesn't move the needle.

### Trick 1 — Incremental token-level parser (append-only)

Instead of re-tokenizing the full buffer on every chunk, keep the tokenizer's state machine alive across chunks. New characters extend the trailing token; characters already emitted as tokens are never revisited.

```dart
class Tokenizer {
  final List<Token> _tokens = [];
  _State _state = _State.start;
  String _buffer = '';

  void feed(String chunk) {
    _buffer += chunk;
    while (_canEmit()) {
      _tokens.add(_emit()); // never touches _tokens already emitted
    }
  }

  void complete() { /* flush trailing token if any */ }
}
```

The block tokenizer is line-based and stateful — fences, lists, blockquotes, and tables all need to know "are we still inside the previous structure?" The inline tokenizer (emphasis, links, code spans) is pure and runs on short paragraph text, so it's fine to re-run from scratch when a paragraph's text changes.

### Trick 2 — Append-only AST construction

The parser converts tokens into AST nodes — but only ever mutates the **trailing path**. A closed paragraph becomes immutable. A new paragraph node gets appended. A list keeps growing items until a blank line closes it.

```dart
sealed class AstNode { final int id; ... }
class Paragraph extends AstNode { final List<InlineSpan> spans; ... }
class CodeBlock extends AstNode { final String? lang; final String code; final bool isComplete; }
// ...

class Parser {
  int _nextId = 0;
  final List<AstNode> _nodes = [];

  void feed(Token token) {
    // Mutate ONLY the trailing node, or append a new node.
    // Closed nodes never get their `id` reassigned.
  }
}
```

This is also where **provisional rendering** falls out for free: an unclosed code block becomes a `CodeBlock(isComplete: false)` node immediately. The renderer sees it, picks up the language from the fence info string, and starts syntax-highlighting in real time. No flash of unstyled content.

### Trick 3 — Diff-stable widget keys

Here's the part that makes Flutter actually behave. Every AST node carries a monotonically increasing `id`. The renderer uses `ValueKey(node.id)` for the widget at each AST position:

```dart
ListView(
  children: [
    for (final node in nodes) _buildBlock(node, key: ValueKey(node.id)),
  ],
)
```

Closed nodes never have their `id` reassigned. So when a new chunk arrives, Flutter's element diff sees the same key in the same slot and **reuses the existing element**. No teardown, no rebuild, no flicker. Only the trailing (open) node's widget rebuilds — which is exactly the work we wanted to do anyway.

This is the line that turns "incremental parser" into "actually smooth UI." Without it, even a perfect parser still gets all its widgets thrown away on every frame.

## The benchmark

Test rig: 5KB markdown response with a mix of paragraphs, two code blocks, a table, and bold/italic — chunked at 4 characters per delivery (about OpenAI's typical streaming cadence). 100 trials, median time.

| Approach | Time to render full stream |
|---|---|
| Naive `flutter_markdown` re-parse | **940 ms** |
| streamdown (incremental + stable keys) | **5 ms** |

That's a **188× speedup** end-to-end. The bigger story isn't the raw number — it's that the cost stops scaling with response length the way the naive approach does. A 100KB response parsed end-to-end in under 10ms.

The micro-benchmark is in [`test/perf_benchmark_test.dart`](https://github.com/jayu1023/streamdown/blob/main/test/perf_benchmark_test.dart) if you want to reproduce or tweak the chunk size.

## What it looks like to use

The whole point was a drop-in replacement, so here's the entire common-case usage:

```dart
import 'package:streamdown/streamdown.dart';

Streamdown(stream: openai.responseStream)
```

For static content:

```dart
Streamdown.text(fullMarkdown)
```

Options you'll actually reach for:

```dart
Streamdown(
  stream: chunks,
  syntaxTheme: SyntaxTheme.githubDark,
  latex: true,                    // enables $..$ / $$..$$ via flutter_math_fork
  selectable: true,               // default
  onLinkTap: (uri) => launchUrl(uri),
  codeBlockBuilder: (lang, code, isComplete) => MyCustomCodeBlock(...),
)
```

Streaming semantics: chunks are **deltas** (newly arrived tokens), not cumulative — matching OpenAI/Anthropic/Gemini SDK conventions and the entire point of not re-parsing. If you need cumulative mode, that's a v0.2 constructor.

## Things I cut from v0.1 on purpose

Shipping in 5 days meant being honest about scope:

- **Loose-list distinction** — any blank line closes a list. Predictable, easy to mentally model, and AI markdown uses blank lines liberally anyway.
- **Nested blockquotes** — flattened to depth=1 in the AST. The tokenizer captures depth, so v0.2 can add this without a breaking change.
- **CommonMark "process emphasis" algorithm** — stack-based delimiter pairing instead. Pathological cases like `*foo**bar*baz**` aren't spec-compliant, but real-world AI markdown always nests cleanly.
- **Mermaid, footnotes, definition lists** — all v0.2+ candidates.

These were deliberate tradeoffs documented in the [decision log](https://github.com/jayu1023/streamdown/blob/main/TRACKER.md#decision-log), not oversights. Predictable behavior on the 95% case beats half-implemented spec compliance.

## What's next

I'm tracking ideas and edge cases in [GitHub Discussions](https://github.com/jayu1023/streamdown/discussions). The v0.2 list right now:

1. Nested blockquotes
2. Loose-list distinction
3. Mermaid diagrams behind a flag
4. Per-line span caching for code blocks (the OPEN code block currently re-highlights on every chunk — fine for ~50-line code blocks, worth caching for longer)
5. Golden-file tests for visual regression

If you're building AI features in Flutter and hit edge cases — markdown that flickers, breaks, or renders wrong — drop them in Discussions with the input and what you expected. That feedback shapes v0.2 more than my roadmap does.

## Try it

```yaml
dependencies:
  streamdown: ^0.0.1
```

- 📦 pub.dev: <https://pub.dev/packages/streamdown>
- 🐙 Repo: <https://github.com/jayu1023/streamdown>
- 💬 Discussions: <https://github.com/jayu1023/streamdown/discussions>

If this saves your week, ⭐ the repo. If it doesn't, open an issue and tell me what broke.
