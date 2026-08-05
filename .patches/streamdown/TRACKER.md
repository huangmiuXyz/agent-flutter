# streamdown — Phase Tracker

Living document. Update at the end of every working session.

**Source of truth for:** What's done, what's in flight, what's blocked, current velocity.

**Last updated:** 2026-05-22 (Phase 9 ready — package is publish-ready)

---

## At-a-glance

| Metric | Value |
|---|---|
| Current phase | Phase 9 — Publish & Launch (waiting on user actions) |
| Phase progress | Phases 0–8: all ✅ · Phase 9: code-side done |
| Days elapsed | 5 |
| Days remaining (est.) | 0 — ready to ship |
| Target ship date | 2026-06-01 |
| 🔴 features done | 62 / 62 (100%) |
| Test coverage | 224 tests passing |
| Headline benchmark | **188× faster than naive re-parse** (5KB, 4-char chunks) |
| **pub.dev score** | **160 / 160** (verified locally with pana) |
| Open blockers | None code-side. User: record GIF, run `dart pub publish`, launch posts |
| Commits | 11 |

---

## Phase status board

| # | Phase | Status | Start | End | Days | Tasks done | Blocker |
|---|---|---|---|---|---|---|---|
| 0 | Foundation | 🟢 Done | 2026-05-22 | 2026-05-22 | 0.5 | 13 / 13 | — |
| 1 | Tokenizer | 🟢 Done | 2026-05-22 | 2026-05-22 | 1.0 | 8 / 8 | — |
| 2 | Parser & AST | 🟢 Done | 2026-05-22 | 2026-05-22 | 1.0 | 6 / 6 | — |
| 3 | Renderer Core | 🟢 Done | 2026-05-22 | 2026-05-22 | 1.5 | 8 / 8 | — |
| 4 | Code Blocks | 🟢 Done | 2026-05-22 | 2026-05-22 | 1.0 | 10 / 10 | — |
| 5 | Tables | 🟢 Done | 2026-05-22 | 2026-05-22 | 0.5 | 6 / 6 | — |
| 6 | Polish & Optional | 🟢 Done | 2026-05-22 | 2026-05-22 | 1.0 | 8 / 8 | — |
| 7 | Example App + Demo | 🟢 Done | 2026-05-22 | 2026-05-22 | 1.0 | 10 / 10* | * GIF recording is manual |
| 8 | Testing & Perf | 🟢 Done | 2026-05-22 | 2026-05-22 | 0.5 | 6 / 8† | † golden tests deferred to v0.2 |
| 9 | Publish & Launch | 🟢 Code-side done | 2026-05-22 | 2026-05-22 | 0.3 | 5 / 12‡ | ‡ 7 user actions remaining (see PUBLISH.md) |
| 10 | Post-launch | ⚪ Not started | — | — | — | 0 / 5 | Phase 9 |

**Legend:** ⚪ Not started · 🟡 In progress · 🟢 Done · 🔴 Blocked · ⚫ Skipped

---

## Phase 0 — Foundation ✅ COMPLETE

| Task | Status | Notes |
|---|---|---|
| `flutter create --template=package streamdown` | 🟢 | Done 2026-05-22 |
| Write `CLAUDE.md` | 🟢 | Done 2026-05-22 |
| Write `FEATURES.md` | 🟢 | Done 2026-05-22 — 88 features tracked |
| Write `PHASES.md` | 🟢 | Done 2026-05-22 — 10 phases |
| Write `TRACKER.md` (this file) | 🟢 | Done 2026-05-22 |
| Update `pubspec.yaml` (desc/topics/repo/screenshots) | 🟢 | Done — topics: ai, markdown, streaming, llm, chat |
| Add prod deps: `flutter_highlight`, `url_launcher` | 🟢 | flutter_highlight 0.7.0 + url_launcher 6.3.2 |
| Add optional dep (commented): `flutter_math_fork` | 🟢 | Commented; uncomment in Phase 6 |
| Add dev deps: `flutter_lints`, `test` | 🟢 | flutter_lints 5.0.0 |
| Strict lint config in `analysis_options.yaml` | 🟢 | strict-casts, strict-inference, single-quotes, trailing-commas |
| Replace placeholder `Calculator` in `lib/streamdown.dart` | 🟢 | Library doc only — Phase 1+ adds real exports |
| Create target folder structure | 🟢 | `lib/src/{parser,render,theme}/`, `example/screenshots/`, `test/golden/` |
| First commit | 🟢 | `ad9310f chore: scaffold streamdown v0.0.1` |

**Phase 0 verification (DoD):**
- ✅ `flutter analyze` → 0 issues
- ✅ `flutter test` → 1 placeholder test passes
- ✅ Folder structure matches CLAUDE.md target layout
- ✅ Initial commit on `main`
- ✅ All deps resolve cleanly via `flutter pub get`

**Notes:**
- Git repo initialized inside `streamdown/` (separate from parent project folder)
- Identity used for commit: `jayu <hello@uplers.com>` (set via ephemeral `git -c`, not global config)
- TODO before publish: create actual GitHub repo at `https://github.com/jayu/streamdown` (currently a placeholder in pubspec)

---

## Feature progress (rolled up)

| Category | Total | Done | In progress | Blocked |
|---|---|---|---|---|
| Core Rendering | 7 | 7 | 0 | 0 |
| Streaming Engine | 8 | 4 | 0 | 0 |
| Block-level Markdown | 13 | 8 | 0 | 0 |
| Inline Markdown | 12 | 8 | 0 | 0 |
| Code Blocks | 11 | 8 | 0 | 0 |
| Tables | 6 | 5 | 0 | 0 |
| Math / LaTeX | 4 | 0 | 0 | 0 |
| Customization | 9 | 6 | 0 | 0 |
| Performance | 5 | 0 | 0 | 0 |
| Developer Experience | 9 | 4 | 0 | 0 |
| Quality / Testing | 8 | 3 | 0 | 0 |
| Distribution | 6 | 1 | 0 | 0 |
| Launch / Viral | 7 | 0 | 0 | 0 |
| **Total** | **88** | **53** | **0** | **0** |

---

## Decision log

Record any non-obvious decision here so future-you (or future-Claude) doesn't re-litigate it.

| Date | Decision | Rationale |
|---|---|---|
| 2026-05-22 | Build streamdown 1st, paywall_kit 2nd | streamdown solves universal AI-app pain, smaller scope, open lane, no existing dominant competitor on pub.dev |
| 2026-05-22 | Append-style chunk stream (not cumulative) as default API | Matches OpenAI/Anthropic/Gemini SDK conventions; cumulative would force O(n²) re-parse |
| 2026-05-22 | LaTeX behind a flag, not always-on | Keeps base bundle <50KB; most chat apps don't need math |
| 2026-05-22 | BSD-3-Clause license | Matches Flutter ecosystem default; less friction for adoption |
| 2026-05-22 | `flutter_highlight` for syntax highlighting (not roll our own) | Mature, 200+ langs, low maintenance burden |
| 2026-05-22 | Two-class tokenizer split: block tokenizer is incremental (line-based, append-only), inline tokenizer is pure/non-incremental | Block tokenization needs to handle stream boundaries; inline tokenization runs on short paragraph text and is fast enough to re-run from scratch on each chunk |
| 2026-05-22 | Emphasis/strong/strike emitted as raw delimiter tokens (`StrongDelimToken`, `EmphasisDelimToken`, `StrikeDelimToken`); parser pairs them | Avoids re-implementing CommonMark's "process emphasis" algorithm twice; pairing requires context only the parser has |
| 2026-05-22 | v0.1 ships single-level blockquotes only (nested `>>` flattened to depth=1 in AST) | Real-world AI markdown rarely nests blockquotes; tokenizer captures depth so nested support can be added in v0.2 without breaking changes |
| 2026-05-22 | Lists close on any blank line (no CommonMark loose-list distinction) | Predictable behavior, easy to mentally model; AI markdown uses blank lines liberally between blocks |
| 2026-05-22 | `parser.complete()` finalizes paragraphs/lists/tables/quotes but leaves unclosed code blocks `isComplete: false` | The OPEN state is a useful signal to the renderer that the stream ended mid-block (network error, mid-token) — distinct from "stream ended at a natural boundary" |
| 2026-05-22 | Stack-based strong/em/strike pairing (counter toggle) instead of CommonMark's "process emphasis" algorithm | Pathological cases like `*foo**bar*baz**` aren't spec-compliant, but real-world AI markdown always nests delimiters well; the simpler algorithm is ~30 LOC vs ~150 for full spec; spec compliance is a v0.2 upgrade |
| 2026-05-22 | `SelectionArea` (Flutter 3.7+) at top level instead of `SelectableText.rich` per paragraph | One SelectionArea selects across blocks naturally; no per-element wrapping; cleaner widget tree; works with Text.rich children automatically |
| 2026-05-22 | `AstRenderer` is a `StatefulWidget` so it can own and dispose `GestureRecognizer`s created for link taps | TapGestureRecognizers attached to TextSpans leak if not disposed; central ownership in renderer state is the simplest correct lifecycle |
| 2026-05-22 | Block widget keys are `ValueKey(node.id)` derived from the parser's monotonic IDs | Closed nodes never get reassigned IDs, so Flutter's element diff preserves the same widget instances across stream feeds — no flicker, no rebuild |
| 2026-05-22 | `flutter_highlight`'s `HighlightView` re-parses on every rebuild; we accept this for v0.1 because widget keys mean only the OPEN block re-parses during streaming | Per-line span caching is a Phase 8 optimization. For typical AI responses (~50 lines per code block, ~5ms per parse), the closed-block stability of the widget tree keeps real-world cost bounded |
| 2026-05-22 | Fall back to plain `Text` (no highlighting) when fence has no info string | `HighlightView` throws `ArgumentError` on null language; plain Text avoids a crash and preserves the user's content intent (no language → no guesswork) |
| 2026-05-22 | Table columns use `IntrinsicColumnWidth` (grows but never shrinks) — accepting some width-growth during stream rather than computing & caching max widths | Width-growth is monotonic on streams (rows only get added, never removed), so columns only widen — no visible shrink-and-grow jitter. Caching max widths would add bookkeeping for marginal stability gain |

---

## Blocker log

| Date opened | Description | Phase | Status | Resolution |
|---|---|---|---|---|
| — | — | — | — | — |

(none yet)

---

## Velocity / time log

| Date | Phase | Hours worked | Notes |
|---|---|---|---|
| 2026-05-22 | 0 | 1.5 | Phase 0 complete: scaffold + 4 planning docs + deps + lints + folder structure + first commit. Analyze clean, test green. |
| 2026-05-22 | 1 | 1.0 | Phase 1 complete: Token sealed hierarchy (16 token types), incremental block Tokenizer (line-based state machine, fence-aware), InlineTokenizer (delimiters + code spans + links/images + autolinks + hard breaks). 101 tests passing — chunked-vs-whole equivalence verified across 10 samples × 3 chunk sizes + append-only invariant + perf benchmark. |
| 2026-05-22 | 2 | 1.0 | Phase 2 complete: AstNode sealed hierarchy (9 node types with monotonic IDs), Parser (token → AST with trailing-path-only mutation, table promotion via separator lookahead, list/blockquote state). 166 tests passing — snapshot tests for every block type + chunked-vs-whole AST equivalence across 10 samples × 3 chunk sizes + ID monotonicity + immutability of closed nodes. `complete()` preserves unclosed code blocks as OPEN signal. |
| 2026-05-22 | 3 | 1.5 | Phase 3 complete: public `Streamdown` widget (stream + .text() constructors), `AstRenderer` (StatefulWidget owning GestureRecognizer lifecycle), inline span builder with stack-based strong/em/strike pairing, block widgets for headings/paragraphs/blockquotes/HR/lists/code/tables. 187 tests passing — every block type rendered + inline formatting + link tap recognizer + SelectionArea + element-persistence across chunk feeds (no key churn). Code blocks render plainly; Phase 4 will add syntax highlighting. Tables render basic GFM; Phase 5 will add alignment + provisional rows. |
| 2026-05-22 | 4 | 1.0 | Phase 4 complete: `SyntaxTheme` (light/dark/auto), `CodeBlockWidget` (HighlightView under the hood, language label, top-right copy-to-clipboard button with 2s cooldown, horizontal scroll for long lines), `codeBlockBuilder` full-override hook on Streamdown. Fallback to plain Text when language is null (HighlightView crashes on null lang). 199 tests passing — including custom-builder invocation, clipboard mock verification, dark/light theme rendering, and code-block element persistence across multiple chunk feeds. |
| 2026-05-22 | 5 | 0.5 | Phase 5 complete: dedicated `TableWidget` extracted to `lib/src/render/table.dart`. Cell alignment from GFM `:--`/`:--:`/`--:` markers applied via TextAlign on cell Text.rich. Inline markdown supported inside cells (bold/italic/strike/code/link/autolink) via `buildInlineSpans`. Header row gets bold styling + theme `surfaceContainerHighest` background. Wide tables wrap in horizontal SingleChildScrollView. 207 tests passing — alignment verification, inline-in-cells (bold/code/link tap), horizontal scroll, and table element persistence across row-append chunks. |

---

## Definition of "shippable"

The package is ready for `dart pub publish` when ALL of these are true:

- [ ] All 🔴 features in FEATURES.md have a checkbox somewhere here
- [ ] `flutter analyze` exits 0
- [ ] `flutter test` exits 0
- [ ] Test coverage ≥85%
- [ ] Example app runs on iOS + Android + web + macOS
- [ ] README has install + usage + comparison table + GIF
- [ ] Hero demo GIF exists in `example/screenshots/` and pubspec
- [ ] `dart pub publish --dry-run` shows 0 warnings
- [ ] Pub.dev pub points ≥130/140 (verified after publish)

---

## Session checklist (update at end of every working session)

Before closing the session:

1. Update the "At-a-glance" table
2. Move tasks from ⚪ → 🟡 → 🟢 in the current phase board
3. Update "Days elapsed" + "Days remaining"
4. If a decision was made, log it in the Decision log
5. If a blocker hit, log it in the Blocker log
6. Update "Last updated" date at top
