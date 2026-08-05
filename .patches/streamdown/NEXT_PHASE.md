# streamdown — Next Phase Implementation Plan

> **Context (as of 2026-05-26):** v0.0.1 is live on pub.dev. 3 days in: **6 likes, 67 weekly downloads, 160/160 pub points**. Tech is best-in-class; distribution is the bottleneck. Direct competitor `gpt_markdown` sits at 297 likes — that's the gap to close.
>
> **Mission for this phase:** Convert quality into adoption. Target → **150 likes + 1,000 weekly downloads + 10 reverse dependents in 60 days.**

---

## Sequencing rule

Phases run sequentially within a track, but **Track A (Trust) and Track B (Distribution) run in parallel.** Track C (v0.2 product) starts only after A is green and B has shipped Phase B1.

```
Track A (Trust)         A1 → A2 → A3
Track B (Distribution)        B1 → B2 → B3 → B4
Track C (Product v0.2)                       C1 → C2 → C3
Track D (Measurement)   D1 ──────── (continuous) ────────
```

---

# TRACK A — Trust & Discoverability (Week 1)

The package looks like a hobby project right now. These three fixes are 30 minutes of work and lift conversion permanently.

## Phase A1 — Publisher verification + version bump (Day 1, 30 min) 🔴 P0

**Goal:** Remove the two silent trust killers on the pub.dev page.

**Tasks:**
- [ ] Verify publisher `dev.jayu` via pub.dev → Admin → Verify domain (DNS TXT record)
- [ ] Bump `pubspec.yaml` version: `0.0.1` → `0.1.0`
- [ ] Remove "🚧 pre-release" line from README header (line 13)
- [ ] Update CHANGELOG with `0.1.0` entry — title it "Stable API surface" not "minor fixes"
- [ ] `dart pub publish --dry-run` → 0 warnings
- [ ] `dart pub publish` → live
- [ ] Tag `v0.1.0` release on GitHub with same changelog

**DoD:**
- pub.dev page shows verified publisher badge
- Version reads `0.1.0`, no "pre-release" string anywhere
- README hero is the GIF + benchmark line, not the status table

**Why it matters:** Devs scanning pub.dev spend ~8 seconds deciding. Unverified + 0.0.1 + "pre-release" = three reasons to leave before reading the README.

---

## Phase A2 — README rewrite (Day 1–2, 2 hrs) 🔴 P0

**Goal:** Lead with the benchmark, not the feature table. The 188× number is the only unfair advantage — it should be unmissable.

**Tasks:**
- [ ] Rewrite README hero: GIF first, then **one line**: *"188× faster than `flutter_markdown` on chunked input. Drop-in API."*
- [ ] Add a single-snippet **"30-second adoption"** block right after the GIF:
  ```dart
  // Before
  Markdown(data: response)
  // After
  Streamdown(stream: openai.responseStream)
  ```
- [ ] Move the comparison table BELOW the snippet
- [ ] Add a "Used by" section at the bottom (start empty, fill as dependents land)
- [ ] Add 3 social proof slots: testimonial quotes from first 3 adopters (collect via GitHub Discussions thread)

**DoD:**
- Above-the-fold of README = GIF + benchmark + snippet (no walls of text)
- Republish (no version bump needed; pub.dev re-renders README on next push)

---

## Phase A3 — Pub.dev topic optimization (Day 2, 15 min) 🟡 P1

**Goal:** Get found by devs searching `openai` / `gpt` / `anthropic` — not just `markdown`.

**Tasks:**
- [ ] Swap topics in `pubspec.yaml`: drop `chat`, add `openai`
- [ ] Verify topics render correctly on pub.dev (max 5 allowed)
- [ ] Republish patch version `0.1.1` if needed for topic update

**Final topic set:** `ai`, `markdown`, `streaming`, `llm`, `openai`

---

# TRACK B — Distribution (Week 1–4)

Pub.dev is not a discovery engine. Growth comes from external backlinks and warm intros.

## Phase B1 — Awesome Flutter PR (Day 2, 45 min) 🔴 P0

**Goal:** Permanent, indexed backlink from the most-starred Flutter resource on GitHub (190K+ stars).

**Tasks:**
- [ ] Fork `Solido/awesome-flutter`
- [ ] Add entry under **"Markdown"** section:
  ```
  - [streamdown](https://github.com/jayu1023/streamdown) - Flicker-free
    streaming markdown renderer for AI chat apps. 188× faster than
    flutter_markdown on chunked input. Drop-in API.
  ```
- [ ] PR title: `Add streamdown — streaming markdown renderer for Flutter AI apps`
- [ ] PR body: 2 sentences + the demo GIF
- [ ] Reply within 24h to any maintainer comments

**DoD:**
- PR merged → indexed by Google within ~7 days
- Track referral traffic via GitHub Insights

**Fallback:** If rejected, target `mhadaily/awesome-flutter-cn` and `nisrulz/flutter-examples` instead.

---

## Phase B2 — Live demo site (Day 3–5, 1 day) 🔴 P0

**Goal:** A hosted side-by-side comparison anyone can share. This is the single biggest viral asset you don't have yet.

**Tasks:**
- [ ] `flutter build web` on `example/lib/scenarios/comparison.dart`
- [ ] Deploy to GitHub Pages: `jayu1023.github.io/streamdown` (free)
- [ ] OR buy `streamdown.dev` ($12/yr) + deploy to Vercel for nicer URL
- [ ] Embed an in-browser mock LLM stream (no API key needed — use bundled sample responses)
- [ ] Add 3 toggleable scenarios: short code-heavy reply, long table-heavy reply, LaTeX-heavy math reply
- [ ] Add a "Copy install line" button + share buttons (Twitter / Reddit / HN intent URLs)
- [ ] Add Plausible / Umami analytics (privacy-friendly, no cookies)
- [ ] Link the demo from README, pub.dev `homepage` field, and Twitter bio

**DoD:**
- URL loads in <2s, demo runs without backend
- Sharable — every Flutter dev who sees this in a tweet should click

**Why it matters:** "Try it in your browser" converts 10–50× better than "go install this package."

---

## Phase B3 — Newsletter + curator outreach (Week 2, 2 hrs) 🟡 P1

**Goal:** One pickup = ~500–2,000 impressions to a high-intent audience.

**Tasks:**
- [ ] Email/DM **Flutter Tap** (`@fluttertap`) — link to live demo, not pub.dev
- [ ] Submit to **Flutter Digest** (flutterdigest.substack.com — open submissions)
- [ ] Submit to **Flutter Insider** newsletter
- [ ] Tweet at `@FlutterDev`, `@dart_lang`, `@vercel` (since streamdown.ai inspired it — they may RT)
- [ ] Post in `r/Flutter` (different sub from r/FlutterDev — different mods, fresh audience) — frame as engineering writeup, not launch
- [ ] Post in Flutter Discord `#showcase` channel

**DoD:**
- 3+ outreach messages sent, 1+ pickup confirmed within 14 days

---

## Phase B4 — Influencer + integration seeding (Week 2–4, ongoing) 🟡 P1

**Goal:** Get streamdown into the next "build a ChatGPT clone in Flutter" tutorial that ships.

**Tasks:**
- [ ] DM 5 Flutter creators (1 of each tier):
  - **Tier 1:** Robert Brunhage, Reso Coder, Code With Andrea (large)
  - **Tier 2:** Hey Flutter, Flutter Mapp, Vandad Nahavandipoor (mid)
  - **Tier 3:** Any creator with a recent AI-chat tutorial (small but targeted)
- [ ] Offer: free early access to v0.2 features + co-promotion of their video
- [ ] Open PRs against 3 popular Flutter AI starters/templates swapping in streamdown:
  - `flyerhq/flutter-chat-ui` consumers
  - Any `dart_openai` example apps
  - `langchain.dart` cookbook examples
- [ ] Reach out to the maintainer of `gpt_markdown` — propose adding streamdown as the "if you need streaming perf" alternative in their README (collaboration > competition)

**DoD:**
- 1+ creator commitment OR 1+ merged integration PR within 30 days

---

# TRACK C — Product v0.2 (Week 3–6)

A new release = relaunch reason = second viral window. Pick ONE bold feature, ship it loud.

## Phase C1 — Choose the v0.2 wedge (Week 3, 1 hr decision) 🔴 P0

**Goal:** Pick the single feature that gives the most relaunch leverage.

**Candidates (pick one):**

| Feature | Build time | Viral angle | Risk |
|---|---|---|---|
| **Mermaid diagram streaming** | 5–7 days | "Render diagrams as they stream" — unique, no Flutter pkg does this | shader/canvas perf |
| **Tool-call UI primitives** | 7–10 days | OpenAI/Anthropic tool-use blocks render natively — huge for agent UIs | API churn risk |
| **Cumulative-stream mode** | 2 days | Lowers adoption friction (some SDKs emit cumulative not delta) | low ceiling, defensive not offensive |
| **Theme presets pack** | 3 days | 8 ready-made themes (ChatGPT, Claude, Gemini, Perplexity look-alikes) — easy demo grid | aesthetic, not technical wedge |

**Recommendation:** **Mermaid streaming.** No Flutter package handles streaming diagrams. Doubles down on the "incremental rendering" technical moat. Gives a killer GIF for relaunch.

**Tasks:**
- [ ] 1-day spike: validate `flutter_mermaid2` or hand-rolled SVG-via-flutter_svg works for partial diagrams
- [ ] Lock the decision, write a 1-page mini-spec in `PHASES.md` extending the existing plan

---

## Phase C2 — Build v0.2 feature (Week 3–5) 🟡 P1

**Goal:** Ship the chosen wedge. Same engineering discipline as v0.1.

**Tasks (templated — fill from chosen feature):**
- [ ] Spec → tests → impl → example scenario → README section
- [ ] Maintain `flutter analyze` 0 + `flutter test` 100%
- [ ] Bench numbers vs naive approach (need a new "Nx faster" headline)
- [ ] New hero GIF for the v0.2 feature alone

**DoD:**
- Feature behind opt-in flag (don't break existing API)
- Bench + GIF + dartdoc complete
- Migration note in CHANGELOG even though it's additive

---

## Phase C3 — Relaunch (Week 5–6, repeat PUBLISH.md playbook) 🟡 P1

**Goal:** Re-trigger every launch surface with fresh content.

**Tasks:**
- [ ] `dart pub publish` v0.2.0
- [ ] New tweet thread (3 tweets, not 1): problem → solution → demo GIF
- [ ] New r/FlutterDev post — frame as "shipped v0.2, here's the engineering writeup"
- [ ] Dev.to part 2 — companion article to the v0.1 piece
- [ ] Email back every newsletter that picked up v0.1 with the new version
- [ ] Quote-tweet your own v0.1 launch tweet with the v0.2 announcement

---

# TRACK D — Measurement (Continuous from Day 1)

What gets measured gets shipped.

## Phase D1 — Weekly metrics log (Day 1 onward, 5 min/week) 🟡 P1

**Goal:** Catch stalls early. If a tactic isn't moving the needle in 7 days, drop it.

**Tasks:**
- [ ] Create `METRICS.md` in repo root (gitignored from public eyes if desired)
- [ ] Every Monday, log:
  - pub.dev: likes, weekly downloads, popularity score, pub points
  - GitHub: stars, watchers, forks, open issues, traffic referrers
  - Demo site (post-B2): unique visitors, install-line copy clicks
  - Reverse dependents (`pub.dev/packages/streamdown` → "Used by")
- [ ] Quarterly review: which channel drove the most likes per hour invested?

**Tracking template:**

```markdown
## Week of YYYY-MM-DD
- Likes: X (+Y from last week)
- Weekly downloads: X (+Y%)
- GitHub stars: X (+Y)
- Demo visits: X
- Top referrer: [source]
- This week's action: [what shipped]
- Next week's bet: [what's next]
```

---

# Kill criteria (when to stop pouring effort in)

Be honest with yourself. If by **Day 60 post-v0.1.0**:
- Likes < 50, AND
- Weekly downloads < 300, AND
- No reverse dependents

→ **Pause active promotion.** Cut to maintenance mode (fix bugs, monthly release cadence). Reallocate the time to `paywall_kit` (next on `IDEAS.md` backlog). The data will tell you the market isn't there at your current distribution reach — better to launch a second package and cross-promote than to flog a flat curve.

If hitting kill criteria, write a `POSTMORTEM.md` capturing what worked / didn't so the next package launch starts smarter.

---

# 60-day target (single number to optimize)

| Metric | Today | Day 30 | Day 60 |
|---|---|---|---|
| Likes | 6 | 50 | **150** |
| Weekly downloads | 67 | 400 | **1,000** |
| Reverse dependents | 0 | 3 | **10** |
| GitHub stars | (track) | (×5) | (×15) |
| Newsletter pickups | 0 | 1 | **3** |

Hitting Day 60 targets puts streamdown in the **top 15% of pub.dev packages by likes** and lands it permanently in pub.dev's "popular" surfaces — which becomes self-sustaining acquisition.

---

# Quick-start checklist (do this week, in order)

```
Day 1 (today)   [ ] A1 — verify publisher + bump to 0.1.0           (30 min)
Day 1           [ ] A2 — rewrite README hero                        (2 hrs)
Day 2           [ ] A3 — swap topics, republish 0.1.1               (15 min)
Day 2           [ ] B1 — submit Awesome Flutter PR                  (45 min)
Day 3–5         [ ] B2 — build + deploy live demo site              (1 day)
Day 1+          [ ] D1 — start METRICS.md, log baseline             (5 min)
```

Total: ~1.5 days of focused work to unlock the next 60 days of growth.

---

## Related docs

- `PUBLISH.md` — initial launch playbook (Phase 9, already executed)
- `PHASES.md` — v0.1 build phases (0–10, complete)
- `FEATURES.md` — full feature catalog (v0.2 features added per Phase C1)
- `IDEAS.md` — next-package backlog (`paywall_kit` queued if streamdown hits kill criteria)
- `DEVTO_ARTICLE.md` — long-form launch article (publish during Phase B3)
