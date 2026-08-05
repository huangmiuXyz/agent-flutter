# streamdown — Next Phase Tracker

Living document for tracking execution of [`NEXT_PHASE.md`](NEXT_PHASE.md).

**Update cadence:** End of every working session, or after the `streamdown-growth-executor` agent completes a phase.

**Last updated:** 2026-05-26 (v0.1.0 shipped + agent-side autonomous tasks complete; awaiting user actions)

**Companion docs:** [`NEXT_PHASE.md`](NEXT_PHASE.md) = the plan · [`PUBLISH.md`](PUBLISH.md) = v0.1 launch (done) · [`TRACKER.md`](TRACKER.md) = v0.1 build (done)

---

## At-a-glance

| Metric | Value | Δ vs last week |
|---|---|---|
| Active phase | A1 (DNS verify) + B1/B3 (user submission) — user actions pending | — |
| Phases done (agent-side) | 5 / 11 (A1 publish, A2, A3, D1, B2 build) | +5 |
| Phases drafted, awaiting user | 2 (B1 PR submit, B3 outreach send) | +2 |
| pub.dev version | **0.1.0** (live) | +0.0.9 |
| pub.dev likes | 6 | — |
| Weekly downloads | 67 | — |
| Reverse dependents | 0 | — |
| GitHub stars | (set baseline next entry) | — |
| GitHub release | v0.1.0 tagged | new |
| Demo site visits | n/a (built locally, not deployed) | — |
| Days since v0.1.0 launch | 0 | — |
| Days to Day-60 review | 60 | — |

---

## Phase status board

### Track A — Trust & Discoverability (Week 1)

| # | Phase | Priority | Status | Est. | Owner | DoD met? |
|---|---|---|---|---|---|---|
| A1 | Publisher verification + version bump → 0.1.0 | 🔴 P0 | 🟡 Bump shipped · DNS verify pending user | 30 min | user (DNS) + agent | 5/6 |
| A2 | README rewrite (benchmark-first hero) | 🔴 P0 | 🟢 Done | 2 hrs | agent | ✅ |
| A3 | Topic optimization (swap `chat` → `openai`) | 🟡 P1 | 🟢 Done | 15 min | agent | ✅ |

### Track B — Distribution (Week 1–4)

| # | Phase | Priority | Status | Est. | Owner | DoD met? |
|---|---|---|---|---|---|---|
| B1 | Awesome Flutter PR | 🔴 P0 | 🟡 Draft ready · user to submit | 45 min | agent (draft) + user (submit) | 1/3 |
| B2 | Live demo site (GH Pages) | 🔴 P0 | 🟢 **DEPLOYED** at https://jayu1023.github.io/streamdown/ | 1 day | agent | 4/7 |
| B3 | Newsletter + curator outreach | 🟡 P1 | 🟡 1/5 sent (Flutter Tap tweet ✅) | 2 hrs | agent (drafts) + user (send) | — |
| B4 | Influencer + integration seeding | 🟡 P1 | ⚪ Not started | ongoing | user-led | — |

### Track C — Product v0.2 (Week 3–6)

| # | Phase | Priority | Status | Est. | Owner | DoD met? |
|---|---|---|---|---|---|---|
| C1 | Choose v0.2 wedge feature | 🔴 P0 | ⚪ Not started | 1 hr | user decision | — |
| C2 | Build chosen v0.2 feature | 🟡 P1 | ⚪ Not started | 1–2 wks | agent + user | — |
| C3 | Relaunch v0.2 (re-run PUBLISH.md) | 🟡 P1 | ⚪ Not started | 1 day | agent + user | — |

### Track D — Measurement (Continuous from Day 1)

| # | Phase | Priority | Status | Est. | Owner | DoD met? |
|---|---|---|---|---|---|---|
| D1 | Weekly metrics log (`METRICS.md`) | 🟡 P1 | 🟢 Done (baseline logged) | 5 min/wk | agent | ✅ |

**Legend:** ⚪ Not started · 🟡 In progress · 🟢 Done · 🔴 Blocked · ⚫ Skipped · ⏸ Paused

---

## Active blockers

| Phase | Blocker | Blocking since | Owner | Resolution |
|---|---|---|---|---|
| A1 (publisher verify) | DNS TXT record needed for `dev.jayu` domain on pub.dev | 2026-05-26 | user | Log in pub.dev → Admin → Verify domain → copy TXT record → add to DNS provider (Namecheap/Cloudflare/etc) → wait ~5 min for propagation → click verify |
| B1 (Awesome Flutter PR) | Needs user GitHub action — fork + submit PR | 2026-05-26 | user | Use the ready submission package below in Phase B1 detail section |
| B2 (demo deploy) | Choice of hosting: GitHub Pages (free) vs custom domain `streamdown.dev` ($12/yr) | 2026-05-26 | user | Decide → agent will deploy. Default recommendation: GH Pages now, custom domain later |
| B3 (outreach send) | Drafts ready; user needs to send across 5 channels over 48h | 2026-05-26 | user | Pacing guide in Phase B3 detail section |

---

## Session log

Append a new row every working session. Newest at the top.

| Date | Phases worked | Status change | Notes |
|---|---|---|---|
| 2026-05-26 (PM2) | B2 deploy, B3 (Flutter Tap) | Demo live at https://jayu1023.github.io/streamdown/ ✅; Flutter Tap tweet posted ✅ | HTTP 200 verified on demo. Tweet: https://x.com/jaylimb03893746/status/2058085290200473678 |
| 2026-05-26 (PM) | A1, A2, A3, B1, B2, B3, D1 | **0.1.0 shipped to pub.dev**; web build green; 2 user-action drafts queued | 215/215 tests pass, 191× benchmark, 0 lint, 0 dry-run warnings. GitHub release v0.1.0 tagged. METRICS.md baseline logged. Awesome Flutter + 5 outreach drafts in this tracker. Web build at `example/build/web/`. |
| 2026-05-26 (AM) | — | Baseline tracker created | NEXT_PHASE.md authored; agent definition installed at `.claude/agents/streamdown-growth-executor.md` |

---

## Phase-by-phase detail

### Phase A1 — Publisher verification + version bump

- **Status:** 🟡 5/6 done — DNS verify pending user
- **Owner:** Mixed — user must add DNS TXT record; agent handled the rest
- **Tasks:**
  - [ ] **User: pub.dev → Admin tab → Verify `dev.jayu` domain → copy TXT record → add to DNS → wait for propagation**
  - [x] Agent: bumped `pubspec.yaml` version `0.0.1` → `0.1.0`
  - [x] Agent: removed pre-release line from `README.md`
  - [x] Agent: added `0.1.0` entry to `CHANGELOG.md` titled "Stable API surface"
  - [x] Agent: ran `dart pub publish --dry-run` → 0 warnings
  - [x] Agent: ran `dart pub publish` → **0.1.0 LIVE** at https://pub.dev/packages/streamdown
  - [x] Agent: tagged `v0.1.0` release on GitHub → https://github.com/jayu1023/streamdown/releases/tag/v0.1.0
- **DoD:**
  - Version reads `0.1.0` ✅
  - No "pre-release" string anywhere in README ✅
  - Verified publisher badge on pub.dev ⏳ (pending user DNS step)
- **Notes:** 215/215 tests pass. Benchmark measured 191.2× (better than headline 188×). Commits pushed to main.

### Phase A2 — README rewrite

- **Status:** 🟢 Done
- **Owner:** Agent
- **Tasks:**
  - [x] Move GIF + 188× benchmark line above feature table
  - [x] Add "30-second adoption" before/after snippet
  - [x] Move comparison table below the snippet
  - [x] Add empty "Used by" section as placeholder
- **DoD:** Above-the-fold = GIF + benchmark + snippet (no walls of text) ✅
- **Shipped in:** 0.1.0 (combined with A1 + A3 for single release)

### Phase A3 — Topic optimization

- **Status:** 🟢 Done
- **Owner:** Agent
- **Tasks:**
  - [x] Edit `pubspec.yaml` topics: drop `chat`, add `openai`
  - [x] Published with 0.1.0 (no separate patch needed)
- **DoD:** pub.dev page shows updated topics — ⏳ wait ~10 min for pub.dev to reindex 0.1.0
- **Final topics:** `ai`, `markdown`, `streaming`, `llm`, `openai`

### Phase B1 — Awesome Flutter PR

- **Status:** 🟡 Draft ready (user to submit)
- **Owner:** Agent drafts, user submits
- **Tasks:**
  - [x] Agent: draft PR title + body + entry markdown
  - [ ] User: fork `Solido/awesome-flutter`, add entry under Markdown section, submit PR
  - [ ] User: reply to maintainer comments within 24h
- **DoD:** PR merged; backlink live

#### 📋 Submission package (ready to copy-paste)

**Fork target:** https://github.com/Solido/awesome-flutter

**File to edit:** `README.md` — find the `### Markdown` section under "Tools and Utilities → Helpers" (search for `flutter_markdown` to locate it).

**Entry to add** (alphabetically — place after `markdown_widget`):

```markdown
* [streamdown](https://github.com/jayu1023/streamdown) - Flicker-free streaming markdown renderer for Flutter AI apps. 188× faster than `flutter_markdown` on chunked input. Drop-in API for ChatGPT-style streaming UIs.
```

**PR title:**

```
Add streamdown — streaming markdown renderer for Flutter AI apps
```

**PR body:**

```
Hi! Adding a new entry under **Markdown**:

**streamdown** — a flicker-free streaming markdown renderer purpose-built for Flutter AI chat apps. It replaces `flutter_markdown`'s "re-parse every chunk" approach with an append-only AST + stable widget keys, so closed blocks never re-render mid-stream.

- 📦 pub.dev: https://pub.dev/packages/streamdown (160/160 pub points)
- 🐙 Source: https://github.com/jayu1023/streamdown
- 📊 Benchmark: ~188× faster than naive re-parse on 5KB markdown streamed in 4-char chunks (OpenAI stream cadence)
- ⚙️ Drop-in API: `Streamdown(stream: openai.responseStream)`
- 🪪 License: BSD-3-Clause

Demo GIF (side-by-side vs flutter_markdown): https://github.com/jayu1023/streamdown/blob/main/example/screenshots/split_screen_demo.gif

Happy to adjust placement, wording, or section if you'd like a different fit. Thanks for maintaining this list!
```

**After-submit checklist:**
- [ ] Star the repo (basic respect)
- [ ] Watch the PR for maintainer feedback — reply within 24h
- [ ] If rejected → fall back to: `mhadaily/awesome-flutter-cn`, `nisrulz/flutter-examples`, `iampawan/FlutterExampleApps`

### Phase B2 — Live demo site

- **Status:** 🟡 1/7 — built locally, awaiting hosting decision
- **Owner:** Agent
- **Tasks:**
  - [x] Agent: ran `flutter build web --release --base-href "/streamdown/"` on example app → output at `example/build/web/` (✅ green build)
  - [ ] **User decision:** GH Pages (free, URL `jayu1023.github.io/streamdown`) OR `streamdown.dev` ($12/yr custom domain)?
  - [ ] Agent: configure deployment (GH Pages branch push, or Vercel link)
  - [ ] Agent: add bundled sample LLM responses (no API key needed)
  - [ ] Agent: wire copy-install-line button + share intent URLs
  - [ ] Agent: add Plausible/Umami snippet (only if user provides domain)
  - [ ] Agent: update README, pub.dev `homepage`, Twitter bio with demo URL
- **DoD:** URL loads in <2s; demo runs without backend; shareable
- **To deploy GH Pages now (fastest path):**
  ```bash
  cd example/build/web
  git init && git checkout -b gh-pages
  git add . && git commit -m "Deploy streamdown demo"
  git remote add origin https://github.com/jayu1023/streamdown.git
  git push -f origin gh-pages
  # Then: GitHub repo settings → Pages → source: gh-pages branch → /root
  ```

### Phase B3 — Newsletter + curator outreach

- **Status:** 🟡 Drafts ready (user to send)
- **Owner:** Agent drafts, user sends
- **Tasks:**
  - [x] Agent: draft Flutter Tap DM
  - [x] Agent: draft Flutter Digest submission
  - [x] Agent: draft Flutter Insider submission
  - [x] Agent: draft r/Flutter post (different from r/FlutterDev)
  - [x] Agent: draft Flutter Discord `#showcase` message
  - [ ] User: send all 5 within a 48h window
- **DoD:** 3+ outreach sent; 1+ pickup within 14 days

#### 📋 Outreach drafts (ready to send)

**1. Flutter Tap (Tweet/DM `@fluttertap`)**

> `@fluttertap` might be useful for your readers — shipped streamdown 0.1.0 today, a flicker-free streaming markdown renderer for Flutter AI apps. 188× faster than flutter_markdown on chunked input. Drop-in API:
>
> `Streamdown(stream: openai.responseStream)`
>
> 📦 https://pub.dev/packages/streamdown

---

**2. Flutter Digest (submit at flutterdigest.substack.com or DM curator)**

Subject: `Package submission: streamdown — streaming markdown for Flutter AI apps`

```
Hi,

Just shipped streamdown 0.1.0 on pub.dev — a streaming markdown renderer
built for Flutter AI chat apps. Think drop-in replacement for
flutter_markdown, but with no flicker on partial code fences, tables, or
LaTeX. ~188× faster than naive re-parse on chunked input.

Drop-in API:
    Streamdown(stream: openai.responseStream)

Would love to be included in an upcoming issue if it fits.

📦 https://pub.dev/packages/streamdown
🐙 https://github.com/jayu1023/streamdown
📊 Benchmark + writeup: https://github.com/jayu1023/streamdown#why-streamdown

Thanks!
— Jayu
```

---

**3. Flutter Insider (submit form / DM)**

Same body as Flutter Digest. Subject:
```
streamdown 0.1.0 — flicker-free streaming markdown for AI chat apps
```

---

**4. r/Flutter post (NOT r/FlutterDev — different sub, fresh audience)**

**Title:**
```
Engineering writeup: how I made markdown rendering 188× faster for Flutter streaming AI apps
```

**Body:**
```
Cross-posting the engineering side of a package I shipped last week
(originally r/FlutterDev got the launch announcement — this one's a
deeper dive on the technique).

The problem: flutter_markdown re-parses the entire response on every
streamed token. For a 2000-token GPT reply that's ~400 full re-parses +
re-highlight passes. You see it as flicker, jumping cursors, and code
blocks flashing unstyled → styled.

The fix is three tricks stacked:

1. **Incremental tokenizer** — new tokens extend the trailing AST node;
   the prefix is never re-scanned.
2. **Provisional rendering** — an unclosed ```dart fence renders as a
   code block *immediately*, then fills in as lines stream. No flash.
3. **Diff-stable widget keys** — every AST node gets a monotonic ID used
   as the Flutter widget key. Flutter's element diff doesn't tear down
   what's already on screen.

Result: 188× faster than naive re-parse on 5KB markdown with 4-char
chunks (roughly OpenAI's stream cadence). 100KB stream parses end-to-end
in under 10ms.

Source + benchmark code:
https://github.com/jayu1023/streamdown
https://pub.dev/packages/streamdown

Happy to dig into any of the three tricks if anyone's curious.
```

---

**5. Flutter Discord `#showcase` channel**

```
Just shipped **streamdown 0.1.0** — a flicker-free streaming markdown
renderer for Flutter AI chat apps 📦

It's a drop-in replacement for `flutter_markdown` that doesn't re-parse
on every chunk. ~188× faster on chunked input. Closed blocks never
re-render mid-stream.

```dart
Streamdown(stream: openai.responseStream)
```

That's the entire API for the common case. Theme, syntax highlighting,
link tap, and selectable text Just Work.

📦 pub.dev: https://pub.dev/packages/streamdown
🐙 source: https://github.com/jayu1023/streamdown

Feedback welcome — especially edge cases I haven't hit yet 🙏
```

**Pacing rule:** Don't blast all 5 in one day. Spread over 48h:
- Day 1 morning: Flutter Tap tweet + Flutter Digest email
- Day 1 evening: Flutter Discord post
- Day 2 morning: Flutter Insider submission
- Day 2 evening: r/Flutter post (Reddit timezone for engagement: post 8–10am EDT)

### Phase B4 — Influencer + integration seeding

- **Status:** ⚪ Not started
- **Owner:** User-led
- **Tasks:**
  - [ ] User: DM 5 Flutter creators (template drafted by agent)
  - [ ] Agent: open PR against `flyerhq/flutter-chat-ui` example app integrating streamdown
  - [ ] Agent: open PR against `dart_openai` examples
  - [ ] Agent: open PR against `langchain.dart` cookbook
  - [ ] Agent: draft friendly outreach to `gpt_markdown` maintainer
- **DoD:** 1 creator commitment OR 1 merged integration PR within 30 days

### Phase C1 — Choose v0.2 wedge feature

- **Status:** ⚪ Not started
- **Owner:** User decision
- **Tasks:**
  - [ ] Agent: 1-day spike on Mermaid streaming feasibility
  - [ ] User: pick feature from candidates table in NEXT_PHASE.md
  - [ ] Agent: write 1-page mini-spec, append to PHASES.md
- **DoD:** Spec locked; feature flag name reserved

### Phase C2 — Build v0.2 feature

- **Status:** ⚪ Not started
- **Owner:** Agent + user review
- **Tasks (templated):**
  - [ ] Spec
  - [ ] Tests
  - [ ] Impl
  - [ ] Example scenario
  - [ ] README section
  - [ ] New benchmark
  - [ ] New hero GIF
- **DoD:** Feature behind opt-in flag; bench + GIF + dartdoc complete; backward compatible

### Phase C3 — Relaunch v0.2

- **Status:** ⚪ Not started
- **Owner:** Agent runs, user posts
- **Tasks:** Re-run PUBLISH.md playbook with v0.2 content
- **DoD:** v0.2.0 live on pub.dev; relaunch posts shipped on all 5 channels

### Phase D1 — Weekly metrics log

- **Status:** ⚪ Not started
- **Owner:** Agent
- **Tasks:**
  - [ ] Agent: create `METRICS.md` with template
  - [ ] Agent: every Monday, append a new row with the week's numbers
- **DoD:** `METRICS.md` exists; at least 1 weekly entry logged

---

## How to run the agent

```
> Use the streamdown-growth-executor agent to start the next phase.
```

The agent will:
1. Read this tracker → identify the next ⚪ Not-started phase by priority
2. Confirm scope with you before any destructive action (publish, push, PR)
3. Execute the phase's agent-owned tasks
4. Update this tracker (status, session log, DoD checklist)
5. Stop after one phase — you decide whether to run the next

See [`.claude/agents/streamdown-growth-executor.md`](.claude/agents/streamdown-growth-executor.md) for the full agent definition.

---

## Day-60 review checkpoint

Set a calendar reminder for **2026-07-25** (60 days after v0.1.0). On that date, check this against `NEXT_PHASE.md` kill criteria:

- Likes ≥ 50? __
- Weekly downloads ≥ 300? __
- Reverse dependents ≥ 1? __

If any are NO across the board → write `POSTMORTEM.md`, pivot effort to `paywall_kit`.
