# Recording the hero GIF

The launch tweet / pub.dev landing depends on a side-by-side GIF showing
`flutter_markdown` (janky) vs `streamdown` (smooth) on the same OpenAI-style
stream. This is Scenario 1 in the example app.

## What to record

- **Resolution:** 1080 × 600 (Twitter-friendly)
- **Frame rate:** 15 fps (small file, perceives smooth)
- **Length:** 10–12 seconds, covering one full stream
- **Output:** `split_screen_demo.gif`, target ≤ 2 MB
- **File location:** `example/screenshots/split_screen_demo.gif`

## Suggested setup

1. Build the example app for desktop:
   ```bash
   cd example
   flutter run -d macos  # or windows / linux
   ```
2. Open the "1. Comparison demo" scenario.
3. Resize the window to ~1100 × 650 (leaves room for chrome).
4. Press **Stream again** to start the canned stream.

## Recording tools

- **macOS:** [Kap](https://getkap.co/) — drag-rectangle, export as GIF
- **Linux:** [Peek](https://github.com/phw/peek) — record area to GIF
- **Windows:** [ScreenToGif](https://www.screentogif.com/)
- **All:** OBS Studio → MP4 → convert to GIF with `ffmpeg`:
  ```bash
  ffmpeg -i in.mp4 -vf "fps=15,scale=1080:-1:flags=lanczos" -loop 0 out.gif
  ```

## After recording

1. Place the GIF at `example/screenshots/split_screen_demo.gif`
2. Uncomment the `screenshots:` block in `pubspec.yaml`
3. Embed in README.md right after the title:
   ```markdown
   ![streamdown vs flutter_markdown](example/screenshots/split_screen_demo.gif)
   ```
4. Commit and you're ready for launch.

## Frame composition tips

- Make sure both panes start blank — press the button after recording starts.
- Zoom in slightly so the headings and code colours are legible at 1080p.
- Avoid moving the cursor through the recording area.
- Use `dart format` on any visible code so it looks tidy.
