import 'package:flutter/material.dart';
import 'package:streamdown/streamdown.dart';

/// Scenario 5 — a long-form static markdown render.
///
/// Demonstrates that streamdown handles real-world documents (multiple
/// headings, lists, code blocks, tables, blockquotes) without breaking.
class LongformScreen extends StatelessWidget {
  const LongformScreen({super.key});

  static const _md = '''
# Why streaming markdown matters

When a language model emits text token-by-token, the UI needs to render
that text *as it arrives* — not wait until the full response is ready.
For markdown specifically, naive renderers re-parse the **entire string**
on every chunk. The result is visible flicker, jumping cursors, and code
blocks that flash unstyled → styled → unstyled.

## The three problems

1. **Re-parsing is expensive.** A single 2000-token response can trigger
   ~400 full-document re-parses. With syntax highlighting, that's
   thousands of token classifications per second.
2. **Widget keys aren't stable.** Without stable keys, Flutter's element
   diff tears down and rebuilds existing widgets on every chunk —
   destroying scroll position, animation state, and selection state.
3. **Incomplete blocks render incorrectly.** A half-finished ` ```dart `
   fence shouldn't appear as plain text until the closing fence arrives.

## How streamdown solves them

We solve all three with one trick: **append-only AST construction with
stable monotonic node IDs.**

- The tokenizer keeps state across chunks; it never re-tokenizes the prefix.
- The parser only mutates the trailing open block. Everything else is frozen.
- Each AST node gets an ID that's used as the Flutter widget key.
- Provisional rendering: a code block appears immediately on `\\`\\`\\`dart`,
  with lines filling in as they stream.

## Try it

```dart
import 'package:streamdown/streamdown.dart';

Streamdown(stream: openai.responseStream)
```

That's the whole API. Pair it with `flutter_animate` and the result is
indistinguishable from ChatGPT or Claude.

## When you'd reach for the static constructor

If you have the full markdown already (cached responses, articles, README
files), use `Streamdown.text(myMarkdown)`. Same renderer, same incremental
parsing under the hood — just no streaming required.

| Use case        | Constructor       |
|-----------------|-------------------|
| AI chat         | `Streamdown(stream: ...)` |
| Cached article  | `Streamdown.text(...)` |
| Blog viewer     | `Streamdown.text(...)` |
| Help docs       | `Streamdown.text(...)` |

## Bigger picture

Streaming UI is the new default for AI applications. Whether you're
building a coding assistant, a research tool, or a customer support bot,
the user experience hinges on how smoothly tokens appear on screen.

> The single most important UX detail in AI products today is
> **smoothness during stream**. Get that right and your app feels alive.
> Get it wrong and it feels broken.

For more, see <https://streamdown.ai/> (the JS package that inspired this
work) or the **streamdown** repo at <https://github.com/jayu1023/streamdown>.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('5. Long-form article')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Streamdown.text(_md),
      ),
    );
  }
}
