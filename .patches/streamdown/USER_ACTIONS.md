# streamdown — Your Action Items

Everything Claude can't do for you. Copy-paste ready. **Total time: ~30 minutes** spread over 48 hours for max effect.

**Updated:** 2026-05-26 (post v0.1.0 ship)
**Source plan:** [`NEXT_PHASE.md`](NEXT_PHASE.md) · **Live tracker:** [`NEXT_PHASE_TRACKER.md`](NEXT_PHASE_TRACKER.md)

---

## 🎯 Quick checklist (do in this order)

- [ ] **Step 1** — Verify publisher domain on pub.dev *(5 min, biggest trust lift)*
- [ ] **Step 2** — Submit Awesome Flutter PR *(10 min, permanent backlink)*
- [ ] **Step 3** — Decide demo hosting → GH Pages or `streamdown.dev` *(2 min decision)*
- [ ] **Step 4** — Send 5 outreach messages (paced over 48 hrs)
- [ ] **Step 5** — Pick v0.2 feature when ready (Week 3)

---

# Step 1 — Verify publisher domain *(5 min)*

**Why:** Right now your pub.dev page shows "unverified uploader" — silent trust killer. A verified badge lifts conversion permanently.

**Where:** https://pub.dev/packages/streamdown/admin

**Steps:**
1. Log in to pub.dev with the same Google account used to publish
2. Click the **Admin** tab on the package page
3. Click **Verify publisher** → enter domain `dev.jayu` (or whatever you own)
4. pub.dev gives you a TXT record like:
   ```
   pub-verification=<long-token>
   ```
5. Add it to your DNS provider (Namecheap / Cloudflare / Google Domains / etc.):
   - Type: `TXT`
   - Host: `@` (or leave blank for root)
   - Value: the full `pub-verification=...` string
   - TTL: default (or 300s for faster propagation)
6. Wait 5–10 min for DNS propagation
7. Back on pub.dev → click **Verify** button

**Done when:** Your pub.dev page shows a verified publisher badge next to "publisher".

---

# Step 2 — Submit Awesome Flutter PR *(10 min)*

**Why:** Permanent Google-indexed backlink from the most-starred Flutter resource on GitHub.

**Steps:**

1. Open https://github.com/Solido/awesome-flutter
2. Click **Fork** (top-right)
3. In your fork, open `README.md` and search for `### Markdown`
4. Add this entry alphabetically (after `markdown_widget`):

```markdown
* [streamdown](https://github.com/jayu1023/streamdown) - Flicker-free streaming markdown renderer for Flutter AI apps. 188× faster than `flutter_markdown` on chunked input. Drop-in API for ChatGPT-style streaming UIs.
```

5. Commit with message: `Add streamdown — streaming markdown renderer for Flutter AI apps`
6. Click **Compare & pull request**
7. Use this PR title:

```
Add streamdown — streaming markdown renderer for Flutter AI apps
```

8. Use this PR body:

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

9. Submit PR
10. ⭐ Star the repo (basic respect)
11. Watch the PR — reply to maintainer comments **within 24 hours**

**Fallback if rejected:** Try these in order:
- https://github.com/mhadaily/awesome-flutter-cn
- https://github.com/iampawan/FlutterExampleApps
- https://github.com/nisrulz/flutter-examples

---

# Step 3 — Decide demo hosting *(2 min)*

The Flutter web demo is already built at `example/build/web/`. Pick one:

### Option A — GitHub Pages (FREE, recommended for now)

URL: `https://jayu1023.github.io/streamdown/`

**Deploy command** (run from project root):

```bash
cd example/build/web
git init && git checkout -b gh-pages
git add . && git commit -m "Deploy streamdown demo"
git remote add origin https://github.com/jayu1023/streamdown.git
git push -f origin gh-pages
```

Then on GitHub: **Settings → Pages → Source: `gh-pages` branch / `/root`** → Save.

Wait ~2 min, then visit `https://jayu1023.github.io/streamdown/` — demo is live.

### Option B — Custom domain `streamdown.dev` ($12/yr)

1. Buy `streamdown.dev` on Namecheap or Cloudflare Registrar (~$12/yr for `.dev`)
2. Tell Claude — agent will redeploy to Vercel with the custom domain pointed at the GH Pages build

**Recommendation:** Do **Option A now**. Upgrade to Option B in Month 2 if traffic justifies it.

### After demo is live (either option):

Tell Claude the URL and the `streamdown-growth-executor` agent will:
- Update the README hero with a "▶ Try it live" link
- Update `pubspec.yaml` `homepage` field
- Re-publish a patch version so pub.dev reflects the new link

---

# Step 4 — Send 5 outreach messages *(paced over 48 hrs)*

**Don't blast all at once.** Stagger across channels for maximum compound effect.

## 📅 Pacing schedule

| Slot | When | Channel | Effort |
|---|---|---|---|
| 1 | Day 1 morning (now) | Flutter Tap (Tweet) | 30 sec |
| 2 | Day 1 morning (now) | Flutter Digest (Email) | 2 min |
| 3 | Day 1 evening | Flutter Discord #showcase | 1 min |
| 4 | Day 2 morning | Flutter Insider (Email) | 2 min |
| 5 | Day 2 morning (8–10 AM EDT) | r/Flutter post | 3 min |

---

## Message 1 — Flutter Tap (Tweet to `@fluttertap`)

**Where:** Twitter / X → compose new tweet
**Recipient:** `@fluttertap` (Flutter newsletter curator)

```
@fluttertap might be useful for your readers — shipped streamdown 0.1.0 today, a flicker-free streaming markdown renderer for Flutter AI apps. 188× faster than flutter_markdown on chunked input. Drop-in API:

Streamdown(stream: openai.responseStream)

📦 https://pub.dev/packages/streamdown
```

Attach the demo GIF (`example/screenshots/split_screen_demo.gif`).

---

## Message 2 — Flutter Digest

**Where:** https://flutterdigest.substack.com (submission form) OR DM curator on Twitter

**Subject:**
```
Package submission: streamdown — streaming markdown for Flutter AI apps
```

**Body:**
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

## Message 3 — Flutter Discord (#showcase channel)

**Where:** https://discord.gg/flutter → `#showcase` channel

```
Just shipped **streamdown 0.1.0** — a flicker-free streaming markdown renderer for Flutter AI chat apps 📦

It's a drop-in replacement for `flutter_markdown` that doesn't re-parse on every chunk. ~188× faster on chunked input. Closed blocks never re-render mid-stream.

```dart
Streamdown(stream: openai.responseStream)
```

That's the entire API for the common case. Theme, syntax highlighting, link tap, and selectable text Just Work.

📦 pub.dev: https://pub.dev/packages/streamdown
🐙 source: https://github.com/jayu1023/streamdown

Feedback welcome — especially edge cases I haven't hit yet 🙏
```

Attach the demo GIF.

---

## Message 4 — Flutter Insider

**Where:** Flutter Insider newsletter submission form / DM curator

**Subject:**
```
streamdown 0.1.0 — flicker-free streaming markdown for AI chat apps
```

**Body:** Same as Flutter Digest message above.

---

## Message 5 — r/Flutter post (NOT r/FlutterDev)

**Where:** https://reddit.com/r/Flutter/submit

> ⚠️ **Important:** Post in `r/Flutter` (different sub from `r/FlutterDev` where you already launched). Different mods, fresh audience. Frame as engineering writeup, not launch announcement.

**Post type:** Text post

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

**Best time to post:** 8–10 AM EDT on a weekday (max Reddit traffic for tech subs).

**After posting:**
- Reply to every comment within 30 min for the first 2 hours
- Don't beg for upvotes — Reddit penalizes it
- Don't repost the launch GIF here; the engineering writeup frame is what makes this post different from the r/FlutterDev one

---

# Step 5 — Pick v0.2 feature *(Week 3 decision)*

**Why:** A new release = relaunch reason = second viral window. You need a fresh "hero feature" to anchor the v0.2 launch posts.

**Decision needed by:** ~2026-06-15 (3 weeks post v0.1.0)

## Candidates

| Feature | Build time | Viral angle | Risk |
|---|---|---|---|
| 🟢 **Mermaid diagram streaming** | 5–7 days | "Render diagrams as they stream" — no Flutter pkg does this | shader/canvas perf |
| 🟡 **Tool-call UI primitives** | 7–10 days | OpenAI/Anthropic tool-use blocks render natively | API churn risk |
| 🟡 **Cumulative-stream mode** | 2 days | Lowers adoption friction (some SDKs emit cumulative) | low ceiling |
| 🟡 **Theme presets pack** | 3 days | 8 ready-made themes (ChatGPT, Claude, Gemini look-alikes) | aesthetic, not technical |

**Claude's recommendation:** **Mermaid streaming.** No Flutter package handles streaming diagrams. Doubles down on the "incremental rendering" technical moat. Gives a killer GIF for relaunch.

**When you decide:** Tell Claude → `streamdown-growth-executor` agent will spike feasibility, write the v0.2 mini-spec, and start the build.

---

# 📊 Day-30 and Day-60 checkpoints

**Track progress in [`METRICS.md`](METRICS.md). Append a row every Monday.**

## Day 30 checkpoint (2026-06-25)

Goals:
- 50+ likes
- 400+ weekly downloads
- 3+ reverse dependents
- 1+ newsletter pickup

If hitting these → keep executing the plan.
If missing on 2+ → reassess which channel isn't converting; ask Claude.

## Day 60 checkpoint (2026-07-25) — KILL CRITERIA

Targets:
- 150+ likes
- 1,000+ weekly downloads
- 10+ reverse dependents

**If by Day 60 you're missing ALL THREE:**
- Pause active promotion
- Cut to maintenance mode
- Pivot effort to `paywall_kit` (next package in `IDEAS.md`)
- Write `POSTMORTEM.md` capturing what worked / didn't

The data will tell you the market isn't there at your current distribution reach — better to launch a second package and cross-promote than to flog a flat curve.

---

# 🔥 Quick wins TODAY (if you only have 30 min)

In this order:
1. ✅ **DNS TXT record for publisher verification** (5 min) — biggest trust lift
2. ✅ **Awesome Flutter PR** (10 min) — permanent SEO backlink
3. ✅ **GH Pages demo deploy** (5 min) — shareable URL
4. ✅ **Flutter Tap tweet + Flutter Discord post** (5 min) — fastest pickup channels
5. ✅ **r/Flutter post tomorrow morning 8 AM EDT** (3 min next morning)

That's the **30-minute sprint** that unlocks the next 60 days of growth.

---

## Related docs in this repo

- [`NEXT_PHASE.md`](NEXT_PHASE.md) — full 4-track growth plan with rationale
- [`NEXT_PHASE_TRACKER.md`](NEXT_PHASE_TRACKER.md) — live phase status board + session log
- [`METRICS.md`](METRICS.md) — weekly metrics log (append-only)
- [`PUBLISH.md`](PUBLISH.md) — v0.1 launch playbook (already executed)
- [`IDEAS.md`](../IDEAS.md) — next-package backlog (`paywall_kit` queued)
- [`.claude/agents/streamdown-growth-executor.md`](.claude/agents/streamdown-growth-executor.md) — agent definition for resuming phase execution
