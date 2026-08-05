# streamdown — Quick Wins (Free + Fast)

**Total time: ~30 minutes. Total cost: $0.** Everything here is free and quick. Bigger items (custom domain, v0.2 build) live in [`USER_ACTIONS.md`](USER_ACTIONS.md).

**Updated:** 2026-05-26 (post v0.1.0 ship)

---

## ⏱ 30-minute sprint order

| # | Action | Time | Cost |
|---|---|---|---|
| 1 | Verify publisher domain (DNS TXT record) | 5 min | $0 |
| 2 | Submit Awesome Flutter PR | 10 min | $0 |
| 3 | Deploy demo to GitHub Pages | 5 min | $0 |
| 4 | Tweet `@fluttertap` ✅ DONE | 30 sec | $0 |
| 5 | Post in Flutter Discord `#showcase` | 1 min | $0 |
| 6 | Email Flutter Digest | 2 min | $0 |
| 7 | Email Flutter Insider | 2 min | $0 |
| 8 | Post in r/Flutter (next morning 8 AM EDT) | 3 min | $0 |

---

# 1. Verify publisher domain *(5 min)*

Removes "unverified uploader" label on pub.dev — biggest trust lift.

1. Go to https://pub.dev/packages/streamdown/admin
2. Click **Verify publisher** → enter `dev.jayu`
3. Copy the `pub-verification=...` TXT record pub.dev gives you
4. Add it to your DNS provider as a TXT record on `@` (root)
5. Wait 5 min, click **Verify** on pub.dev

✅ Done when verified badge appears next to publisher name.

---

# 2. Submit Awesome Flutter PR *(10 min, click-by-click)*

You're adding ONE line to a popular Flutter resource list on GitHub. No command line needed — it's all done in the browser.

## What you're doing (concept first)

GitHub has a list called "Awesome Flutter" maintained by someone else. You can't edit their copy directly. So GitHub's flow is:

1. **Fork** = make your own copy of the list
2. **Edit** = add streamdown to your copy
3. **Pull Request (PR)** = ask the maintainer to merge your line into the real list

When merged, your package shows up in the list forever and Google indexes it. That's the prize.

---

## Click-by-click walkthrough

### Step A — Sign in
1. Go to https://github.com — sign in as `jayu1023` (the account that owns streamdown)

### Step B — Fork the repo *(creates your copy)*
2. Open https://github.com/Solido/awesome-flutter
3. Top-right of the page → click the **"Fork"** button
4. A dialog appears → leave defaults → click **"Create fork"**
5. Wait ~5 sec. You're now redirected to `https://github.com/jayu1023/awesome-flutter` (your personal copy)

### Step C — Edit README.md in YOUR fork
6. You should be on your fork's main page. Click the file **`README.md`** in the file list
7. Click the **pencil icon** (✏️ "Edit this file") in the top-right of the file view
8. The file opens in GitHub's web editor (looks like a big textarea)

### Step D — Find the right section

> ⚠️ **Correction:** Awesome Flutter does NOT have a `### Markdown` section. The right place is `### Text & Rich Content`. I had this wrong in an earlier version of this doc.

9. Press **`Ctrl+F`** (Windows) or **`Cmd+F`** (Mac) in the editor → type `### Text & Rich Content` → press Enter
10. You should jump to a section that looks like this (around line 320):

    ```
    ### Text & Rich Content

    - [Masked Text](https://github.com/benhurott/flutter-masked-text) [275⭐] - Masked text with custom and monetary formatting...
    - [Fleather](https://github.com/fleather-editor/fleather) <!--stargazersfleather-editor/fleather--> - Soft & gentle rich text editor.
    - [AutoSizeText](https://github.com/leisim/auto_size_text) [2111⭐] - Automatically resizes text...
    - [Parsed Text](https://github.com/fayeed/flutter_parsed_text) [222⭐] - Interactive text based on content recognition...
    - [TeX](https://github.com/shah-xad/flutter_tex) [295⭐] - Render Mathematics Equations...
    - [Code Field](https://github.com/BertrandBev/code_field) - Customizable code field widget supporting syntax highlighting...
    ```

11. Find the **last entry** in the section (`Code Field` line)

### Step E — Add the streamdown line

12. Click at the **end** of the `Code Field` line → press **Enter** to start a new line
13. Paste exactly this:

```markdown
- [streamdown](https://github.com/jayu1023/streamdown) <!--stargazersjayu1023/streamdown--> - Flicker-free streaming markdown renderer for Flutter AI chat apps. 188× faster than `flutter_markdown` on chunked input. Drop-in API.
```

14. **Critical formatting checks:**
    - ✅ Line starts with `- ` (dash + space), NOT `* ` — Awesome Flutter uses dashes
    - ✅ Includes the `<!--stargazersjayu1023/streamdown-->` comment — the repo's CI auto-fills star counts later
    - ✅ Description ends with a period
    - ✅ One blank line should separate the section from the next `### Forms` header (don't remove it)

### Step F — Commit the change
14. Scroll to the **bottom** of the page → you'll see a "Commit changes" box
15. In the first text field (commit message) type:
    ```
    Add streamdown — streaming markdown renderer for Flutter AI apps
    ```
16. Leave the radio button on **"Commit directly to the main branch"** (default)
17. Click the green **"Commit changes"** button

### Step G — Open the Pull Request
18. After commit, you're back on your fork's main page
19. You should see a yellow banner: **"This branch is 1 commit ahead of Solido:main"** with a button **"Contribute"** → click **"Contribute"** → **"Open pull request"**
    - *If you don't see the banner:* Go to https://github.com/Solido/awesome-flutter/compare/main...jayu1023:awesome-flutter:main — that opens the PR creation page directly
20. You're now on a "Comparing changes" page → click the green **"Create pull request"** button

### Step H — Fill in the PR form
21. In the **Title** field, paste:
    ```
    Add streamdown — streaming markdown renderer for Flutter AI apps
    ```
22. In the **description** (big text box below the title), paste:

```
Hi! Adding a new entry under **Markdown**:

**streamdown** — a flicker-free streaming markdown renderer purpose-built for Flutter AI chat apps. It replaces `flutter_markdown`'s "re-parse every chunk" approach with an append-only AST + stable widget keys, so closed blocks never re-render mid-stream.

- 📦 pub.dev: https://pub.dev/packages/streamdown (160/160 pub points)
- 🐙 Source: https://github.com/jayu1023/streamdown
- 📊 Benchmark: ~188× faster than naive re-parse on 5KB markdown streamed in 4-char chunks
- ⚙️ Drop-in API: `Streamdown(stream: openai.responseStream)`
- 🪪 License: BSD-3-Clause

Demo GIF: https://github.com/jayu1023/streamdown/blob/main/example/screenshots/split_screen_demo.gif

Thanks for maintaining this list!
```

23. Click the green **"Create pull request"** button

### Step I — Confirm + follow up
24. ✅ PR is submitted. You'll see the new PR page with a URL like `https://github.com/Solido/awesome-flutter/pull/XXXX`
25. **Copy that PR URL** and save it — you'll want to check back on it
26. Click the **⭐ Star** button on `Solido/awesome-flutter` (basic respect — maintainers notice)
27. **Watch for emails from GitHub** — if a maintainer comments asking for changes, reply within 24 hours

---

## What happens next

- Maintainers review PRs periodically (could be a few days to a few weeks)
- If approved → merged → your line is permanently on Awesome Flutter → indexed by Google in ~7 days
- If they ask for tweaks (e.g., move to different section, shorten description) → just edit the same `README.md` in your fork; the PR updates automatically
- If rejected (rare) → try these alternatives in order:
  - https://github.com/iampawan/FlutterExampleApps
  - https://github.com/mhadaily/awesome-flutter-cn
  - https://github.com/nisrulz/flutter-examples

---

## ⚠️ Common mistakes to avoid

- ❌ Don't edit `Solido/awesome-flutter` directly — you don't have permission. You MUST fork first.
- ❌ Don't put the entry in the wrong section. It goes under `### Markdown` (not "AI", not "Streaming")
- ❌ Don't forget the leading `* ` (asterisk + space) — without it the line won't render as a bullet
- ❌ Don't write a long PR description with hype. Maintainers prefer crisp, factual entries.
- ❌ Don't argue if rejected — thank them, move on to the alternatives

---

# 3. Deploy demo to GitHub Pages *(✅ DONE 2026-05-26)*

Claude deployed the `example/build/web/` output to the `gh-pages` branch and GitHub Pages is building.

**Live URL:** https://jayu1023.github.io/streamdown/

✅ Status:
- Web build pushed to `gh-pages` branch
- GitHub Pages enabled on that branch (was already configured)
- `.nojekyll` file added (prevents Jekyll from mangling Flutter's underscore-prefixed assets)
- README updated with "▶ Try it live" link above the demo GIF
- HTTPS enforced

⏳ Allow 2–5 min after deploy for GitHub Pages to finish building before the URL loads.

**To redeploy after a code change** (Claude can do this for you on request):
```bash
cd example && flutter build web --release --base-href "/streamdown/"
cd build/web && git add . && git commit -m "Redeploy" && git push -f origin gh-pages
```

---

# 4. Flutter Tap tweet *(✅ DONE 2026-05-26)*

**Posted:** https://x.com/jaylimb03893746/status/2058085290200473678

✅ Status:
- Tweet live with `@fluttertap` mention
- Demo GIF attached
- Both pub.dev and live-demo URLs included

**Follow-up tasks (next 24 hrs):**
- [ ] Reply to any replies within 30 min for the first 2 hours
- [ ] Pin to profile if not already pinned (Profile → tweet → `...` → Pin to your profile)
- [ ] Quote-tweet your own launch tweet ~6 hours later with a follow-up code snippet or benchmark stat

---

# 5. Flutter Discord post *(1 min)*

Join https://discord.gg/flutter → `#showcase` channel → paste:

````
Just shipped **streamdown 0.1.0** — a flicker-free streaming markdown renderer for Flutter AI chat apps 📦

It's a drop-in replacement for `flutter_markdown` that doesn't re-parse on every chunk. ~188× faster on chunked input. Closed blocks never re-render mid-stream.

```dart
Streamdown(stream: openai.responseStream)
```

That's the entire API for the common case. Theme, syntax highlighting, link tap, and selectable text Just Work.

📦 pub.dev: https://pub.dev/packages/streamdown
🐙 source: https://github.com/jayu1023/streamdown

Feedback welcome — especially edge cases I haven't hit yet 🙏
````

Attach the demo GIF.

---

# 6. Flutter Digest email *(2 min)*

Submit at https://flutterdigest.substack.com or DM the curator on Twitter.

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

# 7. Flutter Insider email *(2 min)*

Same body as Flutter Digest. Subject:

```
streamdown 0.1.0 — flicker-free streaming markdown for AI chat apps
```

---

# 8. r/Flutter post *(3 min — tomorrow 8–10 AM EDT)*

⚠️ Post in **r/Flutter** (NOT r/FlutterDev — different sub, fresh audience).

Go to https://reddit.com/r/Flutter/submit → Text post.

**Title:**
```
Engineering writeup: how I made markdown rendering 188× faster for Flutter streaming AI apps
```

**Body:**
````
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
````

**Rules:**
- Don't beg for upvotes — Reddit penalizes it
- Reply to every comment within 30 min for the first 2 hours

---

## 📅 Recommended pacing (don't blast all at once)

| When | Do |
|---|---|
| **Right now** | Steps 1–3 (DNS, PR, GH Pages) |
| **Today morning** | Steps 4 ✅ + 6 (Twitter ✅ + Flutter Digest email) |
| **Today evening** | Step 5 (Discord) |
| **Tomorrow morning** | Step 7 (Flutter Insider) |
| **Tomorrow 8–10 AM EDT** | Step 8 (r/Flutter) |

Spread = compound impressions across 48 hours = more sustained traffic spike than a single-day blast.

---

## Bigger items (parked in [`USER_ACTIONS.md`](USER_ACTIONS.md))

Skipped from this doc because they cost money OR take more than 30 min:

- ⏳ Custom domain `streamdown.dev` ($12/yr)
- ⏳ v0.2 feature decision + build (1–2 weeks)
- ⏳ Influencer + integration seeding (ongoing outreach)
