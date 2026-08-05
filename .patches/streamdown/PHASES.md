# streamdown — Phase-wise Execution Plan

10 phases, ~10 working days. Each phase has an explicit Definition of Done, the features it delivers (from FEATURES.md), and which Claude Code skill to invoke.

**Sequencing rule:** Phases run sequentially. A phase doesn't start until the previous phase's DoD is green.

**Exception:** Phase 8 (example app) can run in parallel with Phase 9 (testing) if Phase 7 is complete.

---

## Phase 0 — Foundation (Day 1) ✅

**Goal:** Repo scaffolded, planning docs in place, deps resolved, lint clean.

**Tasks:**
- [x] `flutter create --template=package streamdown`
- [x] Write `CLAUDE.md` with project context + skill map
- [x] Write `FEATURES.md` with full feature catalog
- [x] Write `PHASES.md` (this file)
- [x] Write `TRACKER.md` initial state
- [ ] Update `pubspec.yaml` — description, topics, repo URL, screenshots placeholder
- [ ] Add prod deps: `flutter_highlight`, `url_launcher`
- [ ] Add optional dep: `flutter_math_fork` (commented for now)
- [ ] Add dev deps: `flutter_lints`, `test`
- [ ] Strict lint config in `analysis_options.yaml`
- [ ] Replace placeholder `Calculator` class in `lib/streamdown.dart`
- [ ] Create target folder structure (`lib/src/parser/`, `lib/src/render/`, etc.)
- [ ] First commit: `chore: scaffold streamdown v0.0.1`

**DoD:**
- `flutter analyze` exits 0
- `flutter test` exits 0
- Folder structure matches CLAUDE.md target layout
- Initial commit on `main`

**Features delivered:** F-DX-01, F-DX-06, F-DX-07, F-DX-09, F-DIST-05

**Skill to invoke:** none

**Estimated time:** 2 hours

---

## Phase 1 — Tokenizer (Day 2–3)

**Goal:** Append-only lexer that converts a streaming character buffer into a token stream without re-scanning the prefix.

**Tasks:**
- [ ] Design `Token` type (sealed class: `TextToken`, `BoldOpen`, `BoldClose`, `Heading(level)`, `FenceOpen(lang)`, `FenceClose`, `ListMarker`, `TableSep`, etc.)
- [ ] Design `Tokenizer` class with `feed(String chunk) -> List<Token>` interface
- [ ] Implement state machine for ATX headings, paragraphs, lists, blockquotes
- [ ] Implement fence detection (provisional open, lookahead for close)
- [ ] Implement inline tokens: `**`, `*`, `~~`, `` ` ``, `[`, `]`, `(`, `)`
- [ ] Implement table-row detection (pipe + newline)
- [ ] Handle edge cases: backslash escapes, character entities, hard line breaks
- [ ] 60+ unit tests covering each token type

**DoD:**
- Tokenizer can be fed in arbitrary chunk sizes (1 char, 100 chars, whole buffer) and produces identical token sequences
- O(n) time, no quadratic blowup with append
- All 60+ tests pass

**Features delivered:** F-STREAM-01, F-STREAM-05, F-TEST-01

**Skill to invoke:** `flutter-handling-concurrency`, `dart-test-fundamentals`

**Estimated time:** 1.5 days

---

## Phase 2 — Parser & AST (Day 3–4)

**Goal:** Convert token stream into an append-only AST.

**Tasks:**
- [ ] Design `AstNode` sealed class: `HeadingNode`, `ParagraphNode`, `ListNode`, `ListItemNode`, `CodeBlockNode`, `TableNode`, `BlockquoteNode`, `HorizontalRuleNode`, `TextSpanNode`, etc.
- [ ] Implement `Parser` with `feed(List<Token>) -> AstDiff` returning structured diff (new nodes, mutated node)
- [ ] Append-only invariant: only the trailing path can mutate; all earlier nodes are frozen
- [ ] Provisional state on the trailing node (e.g., `CodeBlockNode(isComplete: false)`)
- [ ] Stable node IDs (monotonic counter) for widget keying
- [ ] Snapshot tests: 40+ markdown samples → expected AST

**DoD:**
- Parser handles all v0.1 block types from FEATURES.md
- Feeding a string in chunks produces the same final AST as feeding the whole string at once
- No mutations outside the trailing path
- All snapshot tests pass

**Features delivered:** F-CORE-04, F-STREAM-02, F-STREAM-03, F-TEST-02, F-TEST-04

**Skill to invoke:** `writing-plans`, `dart-test-fundamentals`

**Estimated time:** 1.5 days

---

## Phase 3 — Renderer Core (Day 5)

**Goal:** AST → Widget tree with stable keys. Bare-bones rendering for all block types.

**Tasks:**
- [ ] `AstRenderer` widget that listens to AST stream + rebuilds incrementally
- [ ] Stable widget keys derived from monotonic node IDs
- [ ] Block-level widgets: `_HeadingWidget`, `_ParagraphWidget`, `_BlockquoteWidget`, `_HrWidget`, `_ListWidget`
- [ ] Inline span builder for `TextSpan` (bold, italic, code, links)
- [ ] Theme inheritance from `Theme.of(context)`
- [ ] Selectable wrapper (`SelectableText.rich`)
- [ ] `onLinkTap` callback wired through inline spans
- [ ] Widget tests for each block type

**DoD:**
- All v0.1 block & inline elements render correctly
- No flicker when feeding chunked input (verified by widget test that asserts no key churn)
- Selectable text works; link tap fires callback
- `flutter analyze` clean

**Features delivered:** F-CORE-01, F-CORE-02, F-CORE-05, F-CORE-06, F-CORE-07, F-BLOCK-01, F-BLOCK-03 through F-BLOCK-08, F-INLINE-01 through F-INLINE-08, F-INLINE-11, F-INLINE-12, F-CUSTOM-03, F-CUSTOM-04, F-CUSTOM-06, F-CUSTOM-08, F-TEST-03

**Skill to invoke:** `flutter-expert`, `flutter-add-widget-test`

**Estimated time:** 1 day

---

## Phase 4 — Code Blocks (Day 6)

**Goal:** The killer feature. Incremental syntax-highlighted code with provisional rendering.

**Tasks:**
- [ ] Integrate `flutter_highlight`
- [ ] Per-line highlight caching — don't re-highlight existing lines on append
- [ ] Provisional rendering — render as code block from opening fence, before closing fence arrives
- [ ] Lang detection from fence info string (`dart`, `typescript`, `python`, etc.)
- [ ] Default themes: `github-light`, `atom-one-dark`
- [ ] Theme switch via `syntaxTheme` param
- [ ] Copy-to-clipboard button (top-right overlay)
- [ ] Horizontal scroll for long lines
- [ ] `codeBlockBuilder` escape hatch for full override
- [ ] Tests: chunked code block input → no flash, smooth incremental render

**DoD:**
- Code block highlights correctly during streaming
- Copy button works on all platforms
- Custom builder override works
- Perf: incremental highlight <2ms per line (benchmark)

**Features delivered:** F-BLOCK-09, F-CODE-01 through F-CODE-07, F-CODE-09, F-CUSTOM-01, F-CUSTOM-02

**Skill to invoke:** `flutter-expert`

**Estimated time:** 1 day

---

## Phase 5 — Tables (Day 7)

**Goal:** GFM tables with provisional row rendering and stable column widths.

**Tasks:**
- [ ] Table widget with `IntrinsicColumnWidth` (stable across additions)
- [ ] Parse header row + alignment spec
- [ ] Render rows as they stream (provisional state)
- [ ] Markdown-in-cells (bold, links, inline code)
- [ ] Horizontal scroll wrapper for wide tables
- [ ] Widget + golden tests

**DoD:**
- Tables grow row-by-row without column-width thrash
- Alignment markers work
- Inline markdown inside cells works
- All table widget tests pass

**Features delivered:** F-BLOCK-11, F-TABLE-01 through F-TABLE-05

**Skill to invoke:** `flutter-fix-layout-issues`

**Estimated time:** 0.5 day

---

## Phase 6 — Polish & Optional Features (Day 7–8)

**Goal:** Task lists, strikethrough, images, LaTeX flag, stream lifecycle, error handling.

**Tasks:**
- [ ] Task lists `- [ ]` / `- [x]` (read-only checkboxes)
- [ ] Strikethrough `~~` rendering
- [ ] Inline images `![alt](url)` with `Image.network` + placeholder
- [ ] Bare URL autolinking
- [ ] `flutter_math_fork` behind `latex: true` flag
- [ ] Stream cancellation on dispose
- [ ] `errorBuilder` for stream errors
- [ ] Stream completion finalization for provisional blocks

**DoD:**
- All v0.1 🟡 features land
- LaTeX feature works when flag enabled (verified by widget test)
- No memory leaks on widget dispose (verified by leak test)

**Features delivered:** F-INLINE-04, F-INLINE-08, F-INLINE-09, F-BLOCK-06, F-MATH-01 through F-MATH-04, F-STREAM-06, F-STREAM-07, F-STREAM-08, F-CUSTOM-05

**Skill to invoke:** `flutter-expert`

**Estimated time:** 1 day

---

## Phase 7 — Example App + Demo (Day 8–9)

**Goal:** The example/ folder is the launch demo. Six scenarios. One hero GIF.

**Tasks:**
- [ ] Scenario 1: **Split-screen comparison** — same mock OpenAI stream rendered by `flutter_markdown` vs `Streamdown`. THE hero demo.
- [ ] Scenario 2: Live AI chat (with key field) hitting OpenAI/Claude/Gemini
- [ ] Scenario 3: Theming showcase — 3 syntax themes side by side
- [ ] Scenario 4: Custom `codeBlockBuilder` example
- [ ] Scenario 5: Long-form static render (5000-word article)
- [ ] Scenario 6: LaTeX showcase
- [ ] Mock stream helper utility (`mock_stream.dart`)
- [ ] Record the split-screen GIF at 1080×600, 15fps, ≤2MB
- [ ] Place GIF in `example/screenshots/` and reference in README + pubspec

**DoD:**
- Example app runs on iOS, Android, web, macOS
- All 6 scenarios work without crash
- Hero GIF is in repo and embedded in README
- README shows comparison table + install + basic usage + advanced usage

**Features delivered:** F-DX-03, F-DX-04, F-DX-05, F-LAUNCH-01, F-LAUNCH-07, F-DIST-06

**Skill to invoke:** `flutter-animating-apps`

**Estimated time:** 1 day

---

## Phase 8 — Testing & Performance (Day 9)

**Goal:** ≥85% coverage, headline perf number for marketing.

**Tasks:**
- [ ] Full tokenizer test suite (100+ cases)
- [ ] Full parser AST snapshot tests (40+ cases)
- [ ] Widget tests for every block + inline element
- [ ] Stream replay tests (chunked vs whole)
- [ ] Golden file tests for visual regression
- [ ] Perf benchmark suite vs `flutter_markdown` — measure parse+render time per chunk for a 2000-token GPT response
- [ ] Coverage report — ensure ≥85%
- [ ] CI workflow (GitHub Actions): `flutter analyze` + `flutter test` + coverage upload

**DoD:**
- All tests pass on CI
- Coverage ≥85%
- Benchmark report shows ≥10× speedup on chunked input vs `flutter_markdown`
- CI green badge in README

**Features delivered:** F-PERF-01, F-PERF-02, F-PERF-04, F-PERF-05, F-TEST-01 through F-TEST-06, F-TEST-08, F-DIST-02

**Skill to invoke:** `flutter-testing-apps`, `dart-test-fundamentals`

**Estimated time:** 1 day

---

## Phase 9 — Publish & Launch (Day 10)

**Goal:** Live on pub.dev with viral launch.

**Tasks:**
- [ ] Run pub.dev discoverability checklist (CLAUDE.md)
- [ ] Verify all 🔴 features from FEATURES.md are checked
- [ ] Dartdoc every public symbol
- [ ] Write CHANGELOG.md 0.0.1 entry
- [ ] Create GitHub repo, push, configure issues + discussions
- [ ] `dart pub publish --dry-run` — fix any warnings
- [ ] `dart pub publish`
- [ ] Verify package page on pub.dev — pub points, screenshots, topics
- [ ] **Tweet** with split-screen GIF — tag `@FlutterDev`, `@vercel`
- [ ] r/FlutterDev post: "I built a flicker-free streaming markdown renderer for AI apps"
- [ ] Flutter Weekly newsletter submission
- [ ] Pin GitHub repo to user profile
- [ ] Engage with first comments / issues fast (first 24h matters most)

**DoD:**
- Package live on pub.dev at v0.0.1
- pub.dev shows pub points ≥130/140
- All launch posts published
- README on GitHub renders correctly with GIF

**Features delivered:** F-DX-02, F-DX-07, F-DIST-01, F-DIST-03, F-DIST-04, F-DIST-06, F-LAUNCH-01, F-LAUNCH-03 through F-LAUNCH-07

**Skill to invoke:** none

**Estimated time:** 0.5 day

---

## Phase 10 — Post-launch (Day 11+) [Optional, not on critical path]

**Goal:** Capture momentum, ship 0.1.0 with the 🟡 features people asked for.

**Tasks:**
- [ ] Write technical blog post on incremental-parsing approach (HN submission)
- [ ] Build `streamdown.dev` live demo site (Flutter web)
- [ ] Address GitHub issues from launch wave
- [ ] Ship 0.0.2 / 0.0.3 patches as feedback arrives
- [ ] After 30 days stable → ship 1.0.0

**DoD:**
- Blog post published
- All launch-week issues triaged
- 1.0.0 shipped within 30 days

---

## Total estimate

| Sum | Days |
|---|---|
| Phases 0–9 | 10 working days |
| Buffer (inevitable surprises) | +2 days |
| **Realistic ship date** | Day 12 |

## Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Tokenizer edge cases burn extra day | High | Time-box Phase 1 to 2 days; defer non-critical edge cases to v0.2 |
| `flutter_highlight` perf bad on large blocks | Med | Per-line caching; if still bad, ship without incremental highlight in 0.0.1 |
| Demo GIF takes longer than expected to look good | Med | Record draft Day 7, refine Day 9 |
| Pub.dev pub points dock for missing example/test | Low | Checklist in Phase 9 |
| Someone publishes a competitor first | Low-Med | Move fast, ship Day 10 |
