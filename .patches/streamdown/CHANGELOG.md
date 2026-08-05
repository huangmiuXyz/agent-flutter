# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] — 2026-05-28

### Fixed
- Intra-word underscores no longer trigger italics. Identifiers like
  `macOS_System` or `foo_bar_baz` now render as literal text, matching
  CommonMark §6.2 emphasis rules. `*` is unchanged and still works
  intra-word. ([#2](https://github.com/jayu1023/streamdown/issues/2))

## [0.1.0] — 2026-05-26

Stable API surface. Same engine as 0.0.1, repositioned as the first production
release. Public widget API and chunk semantics are locked for the 0.1.x line.

### Changed
- Marked stable. The `Streamdown` and `Streamdown.text` constructors, the
  `Stream<String>` delta-chunk contract, and the `SyntaxTheme` / `CodeBlockBuilder`
  hooks will not break within 0.1.x.
- Replaced topic `chat` with `openai` for better pub.dev search discoverability
  by AI provider.
- README hero restructured to lead with the headline benchmark (188× faster than
  `flutter_markdown` on chunked input) and a 30-second drop-in snippet.

### Fixed
- Removed the "pre-release" framing from package docs; the engine has been
  battle-passed through 224 tests and a 160/160 pana score since 0.0.1.

## [0.0.1]

Initial pre-release. Flicker-free streaming markdown for Flutter AI apps.

### Added

**Streaming engine**
- Append-only incremental block tokenizer — never re-tokenizes the prefix when
  new chunks arrive.
- Append-only parser builds an AST where only the trailing open node mutates;
  closed nodes are frozen.
- Provisional rendering: a half-finished ` ```dart` becomes a code block
  immediately; tables grow row-by-row with stable column widths.
- Stable monotonic node IDs used as Flutter widget keys — Flutter's element
  diff never tears down already-rendered blocks.
- Stream cancellation on widget dispose; lifecycle-aware finalization.

**Public widget API**
- `Streamdown(stream: ...)` — incremental constructor for AI chat use cases.
- `Streamdown.text(...)` — static constructor for cached or full-text markdown.
- `selectable` (default `true`) — wraps the rendered tree in `SelectionArea`.
- `onLinkTap` — callback fired when a link or autolink is tapped.
- `textStyle`, `padding` — basic styling hooks.
- `syntaxTheme` — code-block color scheme; defaults to `SyntaxTheme.auto`.
- `codeBlockBuilder` — full override for code rendering (line numbers,
  custom themes, etc.).
- `latex` (default `false`) — enable `$...$` and `$$...$$` math via
  `flutter_math_fork`. Disabled by default so dollar amounts (`$10`)
  don't trigger math mode.
- `errorBuilder` — fallback widget when the stream errors.

**Markdown coverage**
- ATX headings H1–H6 using Material's text theme.
- Paragraphs with soft and hard line breaks.
- Ordered, unordered, and task lists (`- [ ]` / `- [x]`).
- Blockquotes.
- Horizontal rules.
- Fenced code blocks with syntax highlighting via `flutter_highlight`
  (200+ languages, GitHub-light / atom-one-dark / auto themes).
- Code block copy-to-clipboard button with a 2-second confirmation state.
- GFM tables with left / center / right alignment and inline markdown
  inside cells.
- Inline formatting: bold, italic, strikethrough, inline code, links,
  autolinks (`<https://…>` and bare `https://…`), images (`![alt](url)`).
- LaTeX math via `flutter_math_fork` when `latex: true`.

**Quality**
- 224 tests covering tokenizer, parser, widget rendering, streaming
  stability, and a `flutter_markdown`-equivalence benchmark.
- Headline benchmark: ~188× faster than naive re-parse on every chunk
  (5 KB markdown, 4-char chunks).
- 100 KB markdown stream parsed end-to-end in single-digit milliseconds.
- GitHub Actions CI: `dart format`, `flutter analyze --fatal-warnings`,
  `flutter test --coverage` on every push and PR.

### Limitations (planned for v0.2)

- Single-level blockquotes only (nested `>>` flattened to depth 1 in the AST).
- Lists close on any blank line — no CommonMark loose-list distinction.
- Stack-based delimiter pairing for **/*/~~ — not fully CommonMark-spec
  compliant for pathological cases like `*foo**bar*baz**`.
- Hero demo GIF lives in `example/screenshots/` and is recorded manually
  by the maintainer before each marketing push.
