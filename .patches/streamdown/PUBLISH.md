# streamdown — publish & launch playbook

## ✅ Already shipped

- ✅ `flutter analyze` — 0 issues
- ✅ `flutter test` — 224 passed
- ✅ `dart format --set-exit-if-changed lib test` — 0 changed
- ✅ `dart pub publish --dry-run` — 0 warnings
- ✅ `pana .` — **160 / 160 pub points**
- ✅ Hero GIF recorded, converted to 1080×702 @ 15fps (793 KB), embedded
- ✅ `dart pub publish` — **0.0.1 LIVE** at <https://pub.dev/packages/streamdown>
- ✅ Twitter launch posted

What's left is staggered multi-platform posting + first-24-hour engagement.

---

## Posting schedule (stagger across platforms — do NOT blast at once)

| When | Where | Effort | ROI |
|---|---|---|---|
| ✅ Done | Twitter / X | — | high |
| **Now** | r/FlutterDev | 5 min | 🔥 highest |
| **+2–4 hrs** | LinkedIn | 3 min | medium |
| **Tomorrow 7–9am EDT** | Hacker News (Show HN) | 5 min | gamble (huge if hits) |
| **This week** | Dev.to article | 30 min | SEO lasts months |
| **This week** | Tweet `@fluttertap` link to the post | 30 sec | newsletter pickup |

Skip these: Flutter Weekly (defunct domain), Product Hunt (wrong audience), Indie Hackers (SaaS-leaning), r/programming (too broad).

---

## 1. Twitter / X (✅ done)

Final tweet that fit under 280 chars:

```
🚀 streamdown 0.0.1 on pub.dev

Flicker-free streaming markdown for Flutter AI apps. 188× faster than flutter_markdown on chunked input — closed blocks never re-render.

Streamdown(stream: openai.responseStream)

https://pub.dev/packages/streamdown

@FlutterDev
```

GIF attached. `@FlutterDev` tag triggers most newsletter curators automatically.

### Engagement follow-up (next 24 hours)
- Reply to every reply on the launch tweet.
- Quote-tweet your own launch tweet ~6 hours later with a follow-up: a single neat code snippet from `example/lib/scenarios/comparison.dart`, or a stat from the benchmark.

---

## 2. r/FlutterDev (do now)

Submit at https://reddit.com/r/FlutterDev/submit. Attach the GIF as media.

**Title:**

```
I built a flicker-free streaming markdown renderer for Flutter AI apps (188× faster than flutter_markdown)
```

**Body:**

```
Hey r/FlutterDev,

Every ChatGPT-style Flutter app I built had the same problem: each new
token triggers a full re-parse of the entire response with flutter_markdown.
Code blocks flash unstyled → styled → unstyled, tables jitter, scroll
position breaks.

Just shipped **streamdown** — a drop-in replacement that keeps an
append-only AST. Closed blocks never re-render. Provisional rendering
handles half-finished code fences. Stable monotonic widget keys mean
Flutter's element diff doesn't tear down what's on screen.

**Headline benchmark:** 188× faster than naive re-parse on 5KB markdown
with 4-char chunks (roughly OpenAI's stream cadence).

**Drop-in usage:**

    Streamdown(stream: openai.responseStream)

Also supports: `Streamdown.text()` for static content, syntax themes,
`codeBlockBuilder` hook, `$..$` / `$$..$$` LaTeX behind a flag, selectable
text by default.

📦 https://pub.dev/packages/streamdown
🐙 https://github.com/jayu1023/streamdown

Feedback welcome — especially markdown edge cases I haven't covered yet.
```

---

## 3. LinkedIn (in a few hours)

No character limit. LinkedIn rewards story-style posts. Attach the GIF.

```
Solo project shipped: streamdown — a flicker-free streaming markdown renderer for Flutter AI apps.

Why? Every ChatGPT-style Flutter app I tried building had the same issue — flutter_markdown re-parses the entire response on every new token. Visible flicker, code blocks flashing unstyled then styled, jumping cursors. Felt broken.

Spent the past 5 days building the fix:
✅ Append-only AST construction with stable widget keys
✅ Provisional rendering for half-finished code fences
✅ Per-block element persistence — closed blocks never re-render
✅ 224 tests, full CI, 160/160 pub.dev score
✅ 188× faster than naive re-parse on chunked input

Drop-in usage:
Streamdown(stream: openai.responseStream)

That's the entire API for the common case.

Now live on pub.dev: https://pub.dev/packages/streamdown
Repo: https://github.com/jayu1023/streamdown

If you're building AI features in Flutter, this might save your week. Feedback welcome 🙏

#Flutter #Dart #AI #OpenSource #MobileDevelopment
```

---

## 4. Hacker News — Show HN (tomorrow 7–9 am EDT)

HN rewards posts that hit the front page early in the day. Post at the start of US working hours on a weekday for the best front-page odds.

Submit at https://news.ycombinator.com/submit.

**Title:**

```
Show HN: Streamdown – flicker-free streaming markdown renderer for Flutter
```

**URL:**

```
https://pub.dev/packages/streamdown
```

**Text (optional but recommended):**

```
Hi HN,

I built streamdown to fix a problem I kept hitting in Flutter AI chat apps:
flutter_markdown re-parses the entire response string on every streamed
token, so code blocks flash unstyled then styled, tables jitter, and the
UI feels broken.

The trick is an append-only AST with monotonic node IDs used as Flutter
widget keys. Closed blocks become Element-stable — Flutter's diff doesn't
tear them down when later tokens arrive. Provisional rendering handles
half-finished code fences (a ```dart with no closing fence renders as a
code block immediately).

Benchmark: 188× faster than naive re-parse on 5KB markdown with 4-char
chunks. 100KB stream parsed end-to-end in under 10ms.

Built it as a solo side project over 5 days. Open to ideas, especially
edge cases in markdown variants I haven't handled.

Source: https://github.com/jayu1023/streamdown
```

### After submitting
- Don't beg for upvotes — HN penalizes it heavily.
- Reply to every commenter within ~30 minutes for the first 2 hours. That signal helps the post climb.

---

## 5. Dev.to article (this week)

Long-form post about the engineering. SEO benefits last months.

**Title ideas (pick one):**

- "How I built a flicker-free streaming markdown renderer for Flutter (and why flutter_markdown isn't enough for AI apps)"
- "The append-only AST trick that makes Flutter AI chat actually smooth"
- "188× faster markdown rendering for Flutter streaming UIs"

**Outline:**

1. The problem — flutter_markdown's re-parse-every-chunk approach + screenshot of the flicker
2. The three tricks combined (incremental tokenizer, append-only AST, stable widget keys)
3. The benchmark methodology + numbers
4. The provisional rendering insight (half-finished code fences)
5. Try it: `Streamdown(stream: openai.responseStream)`
6. Future work — nested blockquotes, loose lists, golden tests

Drop the GIF in section 1. Cross-post to Medium's Flutter Community publication.

---

## 6. Flutter Tap newsletter (30 seconds)

Tweet `@fluttertap` with the pub.dev link. They curate from Twitter:

```
@fluttertap might be relevant for your readers — just shipped streamdown, a flicker-free streaming markdown renderer for Flutter AI apps (188× faster than flutter_markdown).

https://pub.dev/packages/streamdown
```

---

## Engagement checklist (first 24 hours)

- [ ] Pin the launch tweet to your X profile
- [x] Add topics to the GitHub repo (flutter, dart, ai, markdown, streaming, llm, chat) — done via `gh repo edit`
- [x] Tag the release on GitHub — `v0.0.1` live at <https://github.com/jayu1023/streamdown/releases/tag/v0.0.1>
- [x] Open a "Feedback welcome" GitHub Discussion — created at <https://github.com/jayu1023/streamdown/discussions/1> (⚠️ pin it manually in the UI — pinning isn't exposed via API)
- [ ] Reply to every Twitter / Reddit / HN comment within 30 minutes
- [ ] Watch for issues — address any P0 bug within 24h, minor stuff within a week
- [ ] Refresh https://pub.dev/packages/streamdown — confirm the score lands at 160/160 after their scorer runs (~5–10 min)

---

## Already-done checklist (Phase 9)

- [x] Pre-publish quality gates (analyze, test, format, dry-run)
- [x] pana scoring (160/160)
- [x] Public API dartdoc (Streamdown, SyntaxTheme, CodeBlockBuilder)
- [x] CHANGELOG 0.0.1 entry
- [x] Hero GIF recorded + embedded
- [x] `dart pub publish` succeeded
- [x] Launch tweet posted
- [x] Reddit post
- [x] LinkedIn post
- [x] Show HN
- [x] Dev.to article — full draft ready at `DEVTO_ARTICLE.md` (paste body into <https://dev.to/new>, frontmatter handles tags/cover image)
- [x] GitHub: topics + v0.0.1 release + Discussions enabled + welcome thread
- [ ] Pin the welcome Discussion in the UI (one click — API doesn't expose it)
- [ ] Engagement loop (next 24 hours) — reply to every comment within 30 min
