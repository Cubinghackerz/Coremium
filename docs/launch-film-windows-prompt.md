# Coremium for Windows (beta): launch film prompt

Same method as `docs/launch-film-remotion-prompt.md` (code-built with Remotion, reference: github.com/Leonxlnx/claude-launchvideo),
adapted for the Windows desktop app. Paste the block below into Claude Code, started in any folder.

```
FOLDERS
- STEP 0, before anything else: YOU create the project folder. Run `mkdir -p /Users/nirneet/Movies/coremium-windows-film/out`
  and `cd /Users/nirneet/Movies/coremium-windows-film`. I am not creating it for you; do not wait for me.
- Work only in /Users/nirneet/Movies/coremium-windows-film. Remotion project directly in it, outputs in ./out,
  the cloned reference in ./reference.
- Read-only source of truth: /Users/nirneet/Documents/GitHub/Coremium. Read windows/README.md,
  windows/src/Coremium.App/MainWindow.xaml (layout, colors, labels), windows/src/Coremium.App/App.xaml (palette, pill style),
  windows/src/Coremium.Core/Model.cs and Decisions.cs (exact wording), web/src/components/*.tsx (brand voice),
  docs/assets/logo.png. Never write there.

GOAL
Build a 25 to 30 second launch film for "Coremium for Windows (beta)", entirely from code, at the quality of
github.com/Leonxlnx/claude-launchvideo: Remotion + React, 60 fps, 3840x2160 master, one src/timeline.ts driving visuals
AND a Python-synthesized soundtrack, sub-frame motion blur, and an automated audio/picture sync check (fail if any cue
drifts more than one frame). First git clone that repo into ./reference and READ its README, timeline, audio and render
scripts; do not run its code before reading it, and copy only what you understand.

PRODUCT TRUTH (use only this)
Coremium for Windows is a free, open-source desktop app for Windows 10 and 11 (x64). While a game, creative app, dev
tool or local AI model is in front, it moves background apps into Windows efficiency mode (on hybrid Intel CPUs that
means the efficiency cores); the app in front stays smooth; nothing is closed. Per app: Boost, Normal, Yield, Eco.
Modes: Automatic, Balanced, Gaming, Creator, Coding, Local AI. It explains each decision in plain words, Advanced shows
the numbers, Pause restores Windows defaults, it lives in the tray. No admin rights, no network access.
Tagline: "Keep what matters smooth, without closing anything."

HARD RULES
- It is a BETA: show a small "Beta" tag next to the name in the title card and end card.
- No FPS, battery, temperature or "X% faster" claims, no invented numbers or benchmarks.
- The app window is a faithful recreation of MainWindow.xaml (dark window, chip panel left, mode pills, status and
  decision line, app rows with Boost/Normal/Yield/Eco chips, summary strip). Tag it "Illustrated recreation" in the
  first and last seconds. Use generic app names and neutral colored squares as app icons (a game, a browser, a chat app,
  a music app): no real third-party logos.
- No Microsoft or Windows logos, no Start menu or taskbar imitation, no Apple logo. Writing the words "Windows 10 and 11"
  is fine.
- End card: logo, "Coremium for Windows", "Beta", "Free. Open source. No account.", github.com/Cubinghackerz/Coremium.
- Never upload, publish, git push or touch the Coremium repo.

DIRECTION (decide and commit; do not ask me)
- Look: the Coremium site world: pure black, cyan for performance cores, indigo for efficiency cores, amber for Boost,
  mint for Eco; Segoe-like clean sans (use "Inter Tight" or "Hanken Grotesk" from Google Fonts, licensed for video).
- Five acts, about 28 s: (1) black, a tray icon glows bottom-right, a click opens the window with a spring scale-in;
  (2) the chip panel comes alive: core blocks, total load bar; (3) a game becomes active: "Gaming mode activated" types in,
  browser and chat rows slide a tag "Background" in mint while their blocks drift from the cyan cores to the indigo cores;
  (4) quick cuts: mode pills cycle with labels, Advanced flips on and the numbers line resolves, Pause flips and the status
  reads "Paused: Windows default scheduling restored."; (5) logo, tagline, end card with "Beta".
- Motion: spring and expo ease-out only, gentle camera push-ins, mask reveals for text, motion blur on fast moves.
- Sound: synthesize in Python (numpy/scipy, no samples, no copyrighted music): soft sub bed, crisp clicks on UI actions,
  a swell when the window opens, a rising pad when apps move aside, one clean final hit. Loudness -14 LUFS, true peak
  -1 dBTP.

DELIVERABLES (in ./out)
coremium-windows-launch-4k.mp4, coremium-windows-launch-1080p.mp4, coremium-windows-launch-9x16.mp4 (15 s: acts 1, 3, 5),
poster.png, captions.srt, CHECKLIST.md (every on-screen claim mapped to a line in windows/README.md or a source file,
plus the licences of fonts and that all audio is synthesized).

VERIFY, THEN STOP
ffprobe every file (duration, resolution, audio stream present). Extract 8 evenly spaced frames per film and inspect
them for clipped text, wrong labels, missing "Beta" tag, any logo or claim not allowed above. Fix everything in one pass,
re-render once, stop. Ask before installing anything with brew. Finish with a short report: files, runtimes, what is
recreated, and anything I should approve.
```
