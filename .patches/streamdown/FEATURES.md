# streamdown — Feature Catalog

Every capability the package ships (or plans to ship). Each feature has a unique ID for cross-referencing in PHASES.md and TRACKER.md.

**Legend:**
- 🔴 Must-have (v0.1)
- 🟡 Should-have (v0.1 if time permits)
- 🟢 Nice-to-have (v0.2+)

---

## 1. Core Rendering

| ID | Feature | Priority | Notes |
|---|---|---|---|
| F-CORE-01 | `Streamdown` widget — public API entry point | 🔴 | Single widget, simple constructor |
| F-CORE-02 | `Streamdown.text(String)` — static (non-stream) mode | 🔴 | Uses same incremental parser path |
| F-CORE-03 | `Streamdown.cumulative(Stream<String>)` — cumulative buffer mode | 🟢 | For SDKs that emit full string each tick |
| F-CORE-04 | AST node model (headings, paragraphs, lists, tables, code, etc.) | 🔴 | Internal — drives rendering |
| F-CORE-05 | Stable widget keys per AST node | 🔴 | Prevents element rebuild on append |
| F-CORE-06 | Theme inheritance from ambient `Theme.of(context)` | 🔴 | Headings/text use TextTheme by default |
| F-CORE-07 | Dark/light mode auto-switch | 🔴 | Follows Brightness from MediaQuery |

## 2. Streaming Engine

| ID | Feature | Priority | Notes |
|---|---|---|---|
| F-STREAM-01 | Append-only incremental tokenizer | 🔴 | The core moat — never re-tokenize prefix |
| F-STREAM-02 | Append-only parser (token → AST) | 🔴 | New tokens extend trailing AST node |
| F-STREAM-03 | Provisional block detection | 🔴 | Render half-finished code fence as code block immediately |
| F-STREAM-04 | Provisional row rendering for tables | 🔴 | Render rows as they arrive, stable columns |
| F-STREAM-05 | Stream pause / resume safety | 🔴 | Survives backpressure without state corruption |
| F-STREAM-06 | Stream completion detection (done state) | 🔴 | Finalizes provisional blocks correctly |
| F-STREAM-07 | Stream error handling + `errorBuilder` | 🟡 | Graceful display when stream errors mid-render |
| F-STREAM-08 | Stream cancellation on widget dispose | 🔴 | Avoid memory leaks |

## 3. Block-level Markdown

| ID | Feature | Priority | Notes |
|---|---|---|---|
| F-BLOCK-01 | ATX headings `# H1` through `###### H6` | 🔴 | |
| F-BLOCK-02 | Setext headings (`===` / `---` underline) | 🟡 | Less common but in CommonMark |
| F-BLOCK-03 | Paragraphs with soft/hard line breaks | 🔴 | |
| F-BLOCK-04 | Unordered lists (`-` / `*` / `+`) — nested | 🔴 | |
| F-BLOCK-05 | Ordered lists (`1.` / `1)`) — nested, custom start | 🔴 | |
| F-BLOCK-06 | Task lists `- [ ]` / `- [x]` | 🟡 | GFM extension, popular in AI replies |
| F-BLOCK-07 | Blockquotes (nested) | 🔴 | |
| F-BLOCK-08 | Horizontal rules `---` / `***` / `___` | 🔴 | |
| F-BLOCK-09 | Fenced code blocks ` ``` ` | 🔴 | |
| F-BLOCK-10 | Indented code blocks (4-space) | 🟡 | Less common in AI output |
| F-BLOCK-11 | GFM tables with alignment (`:--`, `:--:`, `--:`) | 🔴 | |
| F-BLOCK-12 | Footnotes `[^1]` | 🟢 | v0.2 |
| F-BLOCK-13 | Definition lists | 🟢 | v0.2 |

## 4. Inline Markdown

| ID | Feature | Priority | Notes |
|---|---|---|---|
| F-INLINE-01 | Bold `**` / `__` | 🔴 | |
| F-INLINE-02 | Italic `*` / `_` | 🔴 | |
| F-INLINE-03 | Bold + italic `***` | 🔴 | |
| F-INLINE-04 | Strikethrough `~~` (GFM) | 🔴 | |
| F-INLINE-05 | Inline code `` ` `` | 🔴 | |
| F-INLINE-06 | Inline links `[text](url)` | 🔴 | |
| F-INLINE-07 | Autolinks `<https://...>` | 🔴 | |
| F-INLINE-08 | Bare URL autolinking (GFM) | 🟡 | |
| F-INLINE-09 | Inline images `![alt](url)` | 🟡 | Network image with placeholder |
| F-INLINE-10 | Reference-style links `[text][ref]` | 🟢 | v0.2 |
| F-INLINE-11 | HTML entities (`&amp;`, `&lt;`, etc.) | 🟡 | |
| F-INLINE-12 | Hard line breaks (trailing 2 spaces or `\`) | 🔴 | |

## 5. Code Blocks (the killer feature)

| ID | Feature | Priority | Notes |
|---|---|---|---|
| F-CODE-01 | Language detection from fence info string | 🔴 | ` ```dart` → dart highlighter |
| F-CODE-02 | Per-line incremental syntax highlighting | 🔴 | Don't re-highlight whole block on append |
| F-CODE-03 | `flutter_highlight` integration (200+ languages) | 🔴 | |
| F-CODE-04 | Provisional rendering (renders as code block from opening fence) | 🔴 | Even before closing fence arrives |
| F-CODE-05 | Light & dark syntax themes (github, atom-one-dark, vs2015, etc.) | 🔴 | |
| F-CODE-06 | Copy-to-clipboard button overlay | 🔴 | Daily quality-of-life win |
| F-CODE-07 | Custom `codeBlockBuilder` override | 🔴 | Lets devs swap our impl with theirs |
| F-CODE-08 | Line numbers (optional) | 🟡 | |
| F-CODE-09 | Long-line horizontal scroll | 🔴 | Prevents overflow |
| F-CODE-10 | Word wrap toggle | 🟡 | |
| F-CODE-11 | Diff syntax (`diff` lang with +/- coloring) | 🟡 | Popular in code review |

## 6. Tables

| ID | Feature | Priority | Notes |
|---|---|---|---|
| F-TABLE-01 | Header row parsing | 🔴 | |
| F-TABLE-02 | Alignment from `:--`, `:--:`, `--:` markers | 🔴 | |
| F-TABLE-03 | Provisional row rendering as they stream | 🔴 | Stable column widths |
| F-TABLE-04 | Markdown inside cells (bold, links, inline code) | 🔴 | |
| F-TABLE-05 | Horizontal scroll for wide tables | 🔴 | |
| F-TABLE-06 | Configurable border style (none, light, full) | 🟡 | |

## 7. Math / LaTeX

| ID | Feature | Priority | Notes |
|---|---|---|---|
| F-MATH-01 | Inline math `$...$` | 🟡 | Behind `latex: true` flag |
| F-MATH-02 | Block math `$$...$$` | 🟡 | Behind `latex: true` flag |
| F-MATH-03 | `flutter_math_fork` integration | 🟡 | Optional dep |
| F-MATH-04 | Provisional math rendering (incomplete `$$`) | 🟡 | Skip rendering until close arrives |

## 8. Customization API

| ID | Feature | Priority | Notes |
|---|---|---|---|
| F-CUSTOM-01 | `syntaxTheme` param (code block colors) | 🔴 | |
| F-CUSTOM-02 | `codeBlockBuilder` param | 🔴 | Full override |
| F-CUSTOM-03 | `onLinkTap` callback | 🔴 | Default: opens in browser via `url_launcher` |
| F-CUSTOM-04 | `selectable` toggle (default `true`) | 🔴 | |
| F-CUSTOM-05 | `latex` toggle (default `false`) | 🟡 | |
| F-CUSTOM-06 | `padding` / `textStyle` overrides | 🔴 | |
| F-CUSTOM-07 | Custom `imageBuilder` for `![](...)` | 🟡 | For caching, blur-hash, etc. |
| F-CUSTOM-08 | Custom `linkStyle` | 🔴 | |
| F-CUSTOM-09 | Per-element `builders` map (e.g., override `h1`, `quote`) | 🟢 | v0.2 — like flutter_markdown extensionSet |

## 9. Performance

| ID | Feature | Priority | Notes |
|---|---|---|---|
| F-PERF-01 | <1ms parse-and-render per chunk for typical AI streams | 🔴 | Benchmark vs `flutter_markdown` |
| F-PERF-02 | No widget rebuild for nodes before the trailing edit | 🔴 | Stable keys + `const` widgets where possible |
| F-PERF-03 | Lazy code highlighting (only highlight visible viewport) | 🟢 | v0.2 — for very long responses |
| F-PERF-04 | Bundle size <50KB without optional `flutter_math_fork` | 🔴 | Marketing point |
| F-PERF-05 | Smooth 60fps on Pixel 3a (low-end Android baseline) | 🔴 | |

## 10. Developer Experience

| ID | Feature | Priority | Notes |
|---|---|---|---|
| F-DX-01 | Single-import API: `import 'package:streamdown/streamdown.dart'` | 🔴 | |
| F-DX-02 | Comprehensive dartdoc on all public APIs | 🔴 | For pub.dev API tab |
| F-DX-03 | Example app with 6+ scenarios | 🔴 | Comparison, AI demo, theming, custom builder, error handling |
| F-DX-04 | Mock stream helper (`streamdown_mock_stream`) | 🔴 | Lets devs test without API keys |
| F-DX-05 | Detailed README with GIF, code samples, comparison table | 🔴 | |
| F-DX-06 | `null safety` and `Dart 3` (records, sealed classes) | 🔴 | |
| F-DX-07 | Pub.dev topics: `ai`, `markdown`, `streaming`, `llm`, `chat` | 🔴 | |
| F-DX-08 | Strong typing — no `dynamic` in public API | 🔴 | |
| F-DX-09 | `lints` clean (`flutter_lints` + custom strict rules) | 🔴 | |

## 11. Quality / Testing

| ID | Feature | Priority | Notes |
|---|---|---|---|
| F-TEST-01 | Tokenizer unit tests (100+ cases) | 🔴 | |
| F-TEST-02 | Parser AST snapshot tests | 🔴 | |
| F-TEST-03 | Widget tests for each block element | 🔴 | |
| F-TEST-04 | Stream replay tests (chunked input → expected AST) | 🔴 | |
| F-TEST-05 | Golden file tests (visual regression) | 🟡 | |
| F-TEST-06 | Perf benchmark suite (vs `flutter_markdown`) | 🔴 | Headline marketing number |
| F-TEST-07 | Integration test: live OpenAI/Claude/Gemini stream | 🟡 | Optional, gated by env var |
| F-TEST-08 | ≥85% line coverage | 🔴 | |

## 12. Distribution

| ID | Feature | Priority | Notes |
|---|---|---|---|
| F-DIST-01 | Published on pub.dev | 🔴 | |
| F-DIST-02 | GitHub repo with CI (lint + test on push) | 🔴 | |
| F-DIST-03 | Semantic versioning (start at 0.0.1, push to 1.0.0 after 30 days stable) | 🔴 | |
| F-DIST-04 | CHANGELOG.md with each release | 🔴 | |
| F-DIST-05 | BSD-3-Clause license (Flutter ecosystem default) | 🔴 | |
| F-DIST-06 | Screenshots in pubspec for pub.dev preview cards | 🔴 | |

## 13. Launch / Viral

| ID | Feature | Priority | Notes |
|---|---|---|---|
| F-LAUNCH-01 | Split-screen demo GIF (`flutter_markdown` vs `streamdown`) | 🔴 | The hero asset |
| F-LAUNCH-02 | Live web demo (`streamdown.dev` or GitHub Pages) | 🟡 | |
| F-LAUNCH-03 | Twitter launch thread with comparison code/GIF | 🔴 | |
| F-LAUNCH-04 | r/FlutterDev post | 🔴 | |
| F-LAUNCH-05 | Flutter Weekly submission | 🔴 | |
| F-LAUNCH-06 | Blog post on incremental-parsing technique | 🟡 | HN-bait |
| F-LAUNCH-07 | Demo screen recording from real Claude/GPT stream | 🔴 | |

---

## Feature counts

- 🔴 Must-have: 62
- 🟡 Should-have: 18
- 🟢 Nice-to-have: 8
- **Total: 88 tracked features**
