# streamdown — Claude Code Context

> **Package goal:** Flicker-free streaming markdown renderer for Flutter AI apps. Drop-in replacement for `flutter_markdown` that handles partial code fences, half-finished tables, and mid-stream LaTeX without re-parsing the whole string on every token.
>
> **Inspiration:** Vercel's [streamdown.ai](https://streamdown.ai/) — but native Dart, no JS interop.
>
> **Target:** pub.dev v0.1.0 in ~10 days. Viral launch via split-screen demo GIF.

---

## Project state

| Field | Value |
|---|---|
| Status | 🚧 Day 1 — scaffolded |
| Flutter SDK | 3.35.5 (Dart 3.9.2) |
| Org | dev.jayu |
| Repo | (to publish — pub.dev: `streamdown`) |
| License | (TBD — recommend BSD-3-Clause to match Flutter ecosystem) |

---

## The user (who you're working with)

Senior Flutter dev. **Lazy by design** — wants the shortest path to a working solution. Skip beginner explanations. Give code first, explain only the non-obvious. Prefer pub.dev packages over hand-rolled when reasonable. Don't pad responses.

---

## Available Claude Code skills (use these proactively)

### Local (already installed — invoke via Skill tool)

| Skill | When to use |
|---|---|
| `flutter-expert` | Widget design, Dart idioms, perf questions, build-mode choices |
| `flutter-testing-apps` | Adding widget tests, integration tests, golden tests |
| `writing-plans` | Before a multi-day implementation chunk |
| `executing-plans` | When executing a written plan with checkpoints |
| `subagent-driven-development` | Parallel independent tasks (e.g., tokenizer + renderer in parallel) |
| `simplify` | Code review for the parser/renderer once they exist |
| `claude-api` | If we ever build a live demo that streams from Claude directly |

### Worth installing later (from skills.sh)

| Skill | URL | Why |
|---|---|---|
| `flutter-animating-apps` | skills.sh/flutter/skills/flutter-animating-apps | Smooth typewriter / cursor animations during stream |
| `flutter-handling-concurrency` | skills.sh/flutter/skills/flutter-handling-concurrency | Stream<String> → AST transformer concurrency model |
| `flutter-add-widget-test` | skills.sh/flutter/skills/flutter-add-widget-test | Widget testing patterns |
| `flutter-fix-layout-issues` | skills.sh/flutter/skills/flutter-fix-layout-issues | Diagnose any re-layout / overflow during streams |
| `dart-test-fundamentals` | skills.sh/kevmoo/dash_skills/dart-test-fundamentals | Pure-Dart tests for the tokenizer |
| `vercel/ai-sdk` | skills.sh/vercel/ai/ai-sdk | Reference for streamdown.ai's JS approach |

**skills.sh search note:** the search/topic pages are client-rendered SPAs and don't return content via WebFetch. To browse the catalog, fetch the sitemap directly:
- `https://www.skills.sh/sitemap-skills-1.xml`
- `https://www.skills.sh/sitemap-skills-2.xml`

---

## Architecture (the moat)

Three tricks no Flutter competitor combines today:

1. **Incremental token-level parser** — append-only AST. New tokens extend the trailing node; never re-parse the prefix.
2. **Provisional rendering for incomplete blocks** — half-finished ` ```dart` renders as a code block immediately (lang detected from the fence line). Partial tables render row-by-row with stable column widths. No flash.
3. **Diff-stable widget keys** — every AST node gets a deterministic key so Flutter's element diff doesn't tear down + rebuild on append.

### Public API contract (v0.1 — locked unless we find a real reason to change)

```dart
// Streaming
Streamdown(
  stream: Stream<String> chunkStream,    // append-style chunks (NOT cumulative)
  syntaxTheme: SyntaxTheme.githubDark,   // optional
  latex: false,                          // optional, enables flutter_math_fork
  selectable: true,                      // optional
  onLinkTap: (Uri uri) {},               // optional
  codeBlockBuilder: (lang, code, isComplete) => Widget,  // optional override
)

// Static
Streamdown.text(String fullMarkdown, { ... same options ... })
```

**Chunk semantics:** The stream emits *deltas* (newly arrived tokens), not the cumulative buffer. This matches OpenAI / Anthropic / Gemini SDK conventions and avoids the O(n²) re-parse trap.

If we ever support cumulative streams, we'll add a `Streamdown.cumulative(...)` constructor.

---

## v0.1 scope (10-day ship)

**IN:**
- CommonMark subset: headers, bold/italic, lists (nested), blockquotes, links, inline code
- Code blocks via `flutter_highlight` (incremental, per-line highlighting)
- Tables with provisional row rendering (stable column widths)
- Streaming text node coalescing (one TextSpan per text run, not per character)
- LaTeX via `flutter_math_fork` (optional, behind `latex: true` flag — keeps base bundle small)
- Selectable text + tappable links

**OUT (v0.2+):**
- Mermaid diagrams
- Custom directives / extensions
- Footnotes, definition lists
- Image lazy loading
- Cumulative-stream mode

---

## Build plan (the 10 days)

| Day | Deliverable | Skill to invoke |
|---|---|---|
| 1 | ✅ Scaffold + CLAUDE.md + IDEAS.md | — |
| 2–3 | Incremental tokenizer + AST diffing | `flutter-handling-concurrency`, `writing-plans` |
| 4 | AST → Widget tree with stable keys | `flutter-expert` |
| 5 | Code blocks + provisional fence handling | `flutter-expert` |
| 6 | Tables with provisional rows | `flutter-fix-layout-issues` |
| 7 | LaTeX flag + selectable text + link tap | — |
| 8 | Example app: split-screen demo vs `flutter_markdown` w/ mocked OpenAI stream | `flutter-animating-apps` |
| 9 | Tests + perf benchmark + README + GIF | `flutter-testing-apps`, `dart-test-fundamentals` |
| 10 | `dart pub publish --dry-run` → publish | — |

---

## File layout (target)

```
streamdown/
├── lib/
│   ├── streamdown.dart            # public exports only
│   └── src/
│       ├── streamdown_widget.dart # the Streamdown widget
│       ├── parser/
│       │   ├── tokenizer.dart     # incremental lexer
│       │   ├── ast.dart           # node types
│       │   └── parser.dart        # token → AST (append-only)
│       ├── render/
│       │   ├── ast_renderer.dart  # AST → Widget
│       │   ├── code_block.dart
│       │   ├── table.dart
│       │   └── inline_spans.dart
│       └── theme/
│           └── syntax_theme.dart
├── example/                        # the launch demo app
│   └── lib/main.dart              # split-screen vs flutter_markdown
├── test/
│   ├── tokenizer_test.dart
│   ├── parser_test.dart
│   ├── widget_test.dart
│   └── golden/                    # golden-file tests
└── README.md                       # with the launch GIF embedded
```

---

## Ground rules for Claude in this package

1. **No `// what this does` comments.** Only `// why` comments when the constraint isn't obvious from the code.
2. **No premature abstraction.** Three similar branches > a class hierarchy.
3. **Match existing patterns** before introducing new ones. (After first files exist, read them first.)
4. **Run `flutter analyze` before declaring a task done.** Fix lint errors, don't ignore them.
5. **Run `flutter test` before committing.** Don't skip tests to push fixes.
6. **Use the available skills proactively.** If a task fits a skill listed above, invoke it.
7. **Don't write new files unless the file plan requires it.** Edit existing ones.
8. **Keep `pubspec.yaml` deps minimal.** Each dep is a future maintenance burden and a perf hit. Adding a dep needs a reason.

---

## Pub.dev discoverability checklist (before publish)

- [ ] `description`: <60 chars, includes "streaming" + "markdown"
- [ ] `homepage`: GitHub repo URL
- [ ] `repository`: same GitHub URL
- [ ] `issue_tracker`: GitHub issues URL
- [ ] `topics`: `ai`, `markdown`, `streaming`, `llm`, `chat`
- [ ] `screenshots`: at least 1 GIF in README + 1 in pubspec
- [ ] README with 4 sections: install, basic usage, comparison table vs flutter_markdown, advanced usage
- [ ] CHANGELOG.md with 0.0.1 entry
- [ ] LICENSE file (BSD-3-Clause recommended)
- [ ] `dart pub publish --dry-run` passes with 0 warnings
- [ ] All public APIs have dartdoc comments (for pub.dev API tab)

---

## Viral launch playbook (day 10)

1. **Tweet** with split-screen GIF (flutter_markdown janky vs streamdown smooth on same OpenAI stream). Tag `@FlutterDev`, `@vercel`.
2. **r/FlutterDev** post: "I built a flicker-free streaming markdown renderer for AI apps"
3. **Flutter Weekly** newsletter submission
4. **Blog post** (day 12–14) on the incremental-parsing technique — HN-bait

---

## Related project files

- `../IDEAS.md` — full package idea backlog (paywall_kit queued for after this ships)
- `~/.claude/projects/-Users-limbanijayhasmukhbhai-Downloads-jayu-pcakage/memory/` — persistent memory across sessions
