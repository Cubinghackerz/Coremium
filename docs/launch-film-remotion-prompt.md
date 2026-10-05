# Coremium launch film: code-built, Remotion (reference: Leonxlnx/claude-launchvideo)

The reference project (MIT) makes a 33 s film entirely from code: Remotion renders React components at 60 fps, a single
`timeline.ts` drives both visuals and a Python-synthesized soundtrack, motion blur comes from sub-frame accumulation, and the
build fails if audio and picture drift apart. Coremium can use the same method, with one advantage: the UI is ours, so the
film can show a faithful recreation of the real panel with perfect framing, no screen-recording permissions, and no personal
data on screen.

Before running anything from the reference repo, vet it: ask Claude to run the `skill-security-review` skill on a fresh
clone (static read only), then read its `package.json` scripts. Copy ideas, not code you have not read.

## Paste this into Claude Code, started in any folder (it creates `~/Movies/coremium-film` itself)

```
FOLDERS
- STEP 0, before anything else: YOU create the project folder. Run `mkdir -p /Users/nirneet/Movies/coremium-film/out` and
  `cd /Users/nirneet/Movies/coremium-film`. I am not creating it for you; do not wait for me.
- Work only in /Users/nirneet/Movies/coremium-film. Put the Remotion project
  directly in it; outputs go to /Users/nirneet/Movies/coremium-film/out, the cloned reference to ./reference.
- Read-only source of truth: /Users/nirneet/Documents/GitHub/Coremium (README.md, docs/index.html, docs/assets/logo.png,
  Sources/Coremium/Notch/NotchViews.swift, Sources/Coremium/Chip/ChipView.swift). Never write there.

GOAL
Build a 30 to 36 second launch film for Coremium, entirely from code, at the quality of github.com/Leonxlnx/claude-launchvideo
(Remotion + React, 60 fps, 3840x2160 master, a single timeline.ts that drives visuals AND a procedurally synthesized
soundtrack, sub-frame motion blur, and an automated audio/picture sync check). Study that repo first (git clone it into
./reference, read only: README, timeline.ts, the audio synthesis script, the render script; do NOT run its code until you
have read it, and do not copy code you have not understood). Then design our own film.

PRODUCT TRUTH (use only this; read ~/Documents/GitHub/Coremium/README.md and docs/index.html for exact wording)
Coremium is a free, open-source macOS notch app. While you play, render, code or run a local model it moves background
apps to the efficiency cores; the app in front stays smooth; nothing is closed. Per app: Boost, Normal, Yield, Eco.
Modes: Automatic, Balanced, Gaming, Creator, Coding, Local AI. It explains each decision ("Gaming mode activated. Roblox
became active. Chrome and Discord moved to Yield, Spotify to Eco."), Advanced shows the numbers, Pause restores macOS
defaults. Tagline: "Keep what matters smooth, without closing anything."
HARD RULES: no FPS, battery, temperature or "X% faster" claims; no invented numbers; the on-screen app UI is a faithful
recreation of the real panel (see the files listed under FOLDERS for layout, labels and colors) and must carry a small "Illustrated recreation" tag in the first and last
seconds; end card says "Free. Open source. No account." plus github.com/Cubinghackerz/Coremium and "Not affiliated with
Apple." Never upload or publish anything.

DIRECTION (decide and commit; do not ask me)
- Look: the landing page world (docs/index.html): pure black, Instrument Serif display + Hanken Grotesk, cyan for
  performance cores, indigo for efficiency cores, amber for Boost. Minimal, slow, confident; one idea per beat.
- Story in five acts, about 33 s: (1) black screen, the notch appears at the top and breathes once; (2) the panel unfolds
  from the notch with a spring, chip and core bars alive; (3) eleven cores as blocks: apps crowd onto the performance cores,
  then a click on Yield sends Chrome and Discord drifting to the efficiency cores while the game keeps its cores;
  (4) the decision line types in ("Gaming mode activated. ..."), modes cycle with their labels, Advanced flips on and the
  numbers resolve; (5) Pause, then the logo, tagline and end card.
- Motion: spring/ease-out-expo only, no bounce gimmicks; camera push-ins on the notch; text reveals by mask, not fade-slide
  on everything; motion blur on fast moves.
- Sound: synthesize it yourself in Python (numpy/scipy): soft sub bed, ticks for clicks, a low swell on the panel unfold, a
  gentle rising pad on the "cores move" beat, a clean final hit. Loudness -14 LUFS, true peak -1 dBTP. No samples, no
  copyrighted music.

BUILD PLAN
1. npm create video (Remotion), TypeScript, 3840x2160 @ 60 fps (also support a 1920x1080 preview via an env flag).
2. src/timeline.ts: one source of truth for act boundaries, cues (clicks, swells, hits) and text. Export cue times to
   JSON for the audio script.
3. Components: Notch, Panel (mode pills, status line, decision line, app rows with Boost/Normal/Yield/Eco chips),
   ChipDie (pins, Apple logo via the SF-style glyph is NOT allowed: draw a neutral chip mark instead and label it "M3 Pro"
   text only), CoreStrip (5 performance + 6 efficiency blocks), CursorClick, EndCard. Match real labels exactly.
4. scripts/audio.py from the cue JSON; scripts/verify_sync.py fails the build if any cue drifts more than 1 frame.
5. Motion blur: render with sub-frame accumulation like the reference (or Remotion's built-in motion blur if equivalent),
   preview render without blur for speed.
6. Outputs: out/coremium-launch-4k.mp4, out/coremium-launch-1080p.mp4, out/coremium-launch-9x16.mp4 (15 s cut: acts 2, 4, 5),
   out/poster.png, out/captions.srt. Mux audio with ffmpeg (ask before installing anything with brew).
7. Verify: ffprobe every file (duration, resolution, audio stream), extract 8 evenly spaced frames per film and inspect
   them for clipped text, wrong labels, off-brand colors, anything that is not in the PRODUCT TRUTH. Fix, re-render once,
   stop. Write out/CHECKLIST.md mapping every on-screen claim to a README line or UI file.

STOP RULES
Only create files under /Users/nirneet/Movies/coremium-film. Do not touch the Coremium repo, do not git push, do not upload. Finish
with a short report: files, runtime, what is recreated vs real, and anything I should approve.
```

## After it renders
Review the 1080p first. Ask Claude for changes by act ("slow act 3 by 20%", "make the click sound softer"), since the
timeline is one file. Real screen-recorded shots can still be dropped in for authenticity: record the live notch with
`Shift+Command+5` and add it as a short cut-in; the recreation keeps everything else consistent.
