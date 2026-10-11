# Coremium launch film: "Two ways in" (the notch and the window)

A fresh launch film for the current app. It is built on **real footage of the running app**, recorded on a Mac, plus
motion graphics for the type and the transitions. It does not recreate the UI. That is the main difference from
`launch-film-hyperframes-prompt.md`, which recreated a 2.0 UI in HTML.

The story: one engine, two surfaces. Coremium lives in the notch, and with one click it becomes a normal window. The film
never claims a speed-up, a battery, a temperature or a frame rate. It shows what the app does and what it measured.

Paste the block below into Claude Code, started in any folder. Plan first; ask me once before any step that loads the CPU.

```
ROLE
You are a launch director, a motion designer and an editor. Make the "Two ways in" launch film for Coremium, a free,
open-source Mac app. The bar is a calm, precise product film (think Linear, Raycast, Things): real product, real
motion, very few words, and no claim the app cannot back up. Make every creative decision yourself. Ask me only:
(a) before anything that loads the CPU (recording with the app open at length, rendering at 4K), (b) before brew
installs, (c) before anything outward-facing (upload, post, push, release). Work until every QA gate passes.

PRIME DIRECTIVE: TRUTH OVER DRAMA
- Every on-screen word maps to a line in the README, a Swift string, or something visible in footage. CHECKLIST.md
  proves it.
- Nothing is faked. Footage is captured from the app running on this Mac. Editing may cut, crop, scale, dissolve or
  retime whole clips. It may NOT change a number, a label, a status line, or the order of events inside a capture.
- Never show the proof strip's "Coremium overhead …" figure in frame. It moves from one reading to the next, the film
  makes no overhead claim, and a number on screen would be read as one.
- Never show Insights cards with an energy estimate or a temperature reading ("Energy saved (est.)", "Hot during
  boosts"). The film mentions no watts, battery, temperature, frame rate or percentage speed-up.

SOURCE OF TRUTH (read-only; never write to the Coremium repo)
- README.md: the only source of claims. Current bullets: Modes, Four choices per app, Advanced mode, Memory guard,
  Storage, Live notch, Window, Live graphs, Insights, Learns locally, Automation, Updates.
- Sources/Coremium/Notch/NotchViews.swift and Notch/Tabs/*.swift: exact labels (tabs: Apps, Insights, Storage, System,
  Simulate, Guide, Settings; mode names; the Advanced capsule; the window button and its tooltip).
- Sources/Coremium/Window/DashboardWindowController.swift: the window's own labels ("Notch" or "Pill" return button,
  "Advanced", the tiles "CPU", "GPU", "Memory", "Cores").
- Sources/Coremium/Shared/PerformancePanel.swift and Graphs.swift: the 2 min / 30 min spans and the legends.
- Sources/Coremium/Notch/Tabs/GuideSettingsTabs.swift: the "Window mode" row wording.
- Sources/Coremium/Engine/AppEngine.swift: decision wording ("mode activated", "moved to").
- Sources/Coremium/App/CoremiumApp.swift: menu items ("Open Coremium Window", "Window mode (no notch)").
- web/src/components/notch-gallery.tsx: the captions already approved for the site. Reuse them; do not contradict them.
- docs/assets/logo.png: the logo.

CONCEPT (decided; do not reopen without me)
- Title card line: "Two ways in." Subline: "Same engine, one switch."
- The notch is where Coremium starts. The window is the same app in a normal window. The film's central image is the
  moment one becomes the other: a single click, a fold and an unfold, with no cut.
- Tone: quiet confidence. Short declarative lines. No hype words ("insane", "revolutionary", "blazing").

THE FOOTAGE PROTOCOL (do this before any editing)
1. Use a Mac with a notch and the current build of Coremium. Install the Release build (scripts/build.sh), or the
   Debug build if the Release build is not yet ready; say which in CHECKLIST.md.
2. Make the demo session neutral: open two or three ordinary apps (a browser, a music app, a writing app). Avoid
   third-party logos in close-ups. If a real app name must show, keep it small and out of hero shots.
3. SETTLE RULE: opening the panel or the window causes a short CPU spike. Start every capture at least 5 seconds after
   the open. Never cut into the first 5 seconds of an open. Record that rule in CHECKLIST.md. Never speed-ramp a spike
   to hide it.
4. Capture each shot as a separate clip with screencapture (-v for video, -R for a region, or a window capture). Name
   clips by beat: 02-notch-open.mov, 03-apps-row.mov, 04-decision.mov, 05-window-switch.mov, 06-graphs-2min.mov,
   07-advanced.mov, 08-settings-window-mode.mov, 09-storage-review.mov. Keep the raw clips in film/raw and never edit them
   in place.
5. Advanced mode: set it with `defaults write com.cubinghackerz.coremium advancedMode -bool true`, restart Coremium,
   record, then set it back to false and restart. Record the state of each setting in CHECKLIST.md.
6. Window mode: toggle with the Settings row "Window mode" or the menu-bar item, never with a hidden flag. Record it.
7. Live graphs need about 2 minutes of history before the 2 min view is full. Start the window, wait, then record. The
   film never shows the chart before it has data.
8. Verify each clip with ffprobe (duration, size, fps). Keep only the clips that pass the settle rule.

BEATS (45.0 s, 16:9; every cue time lives in film/timeline.json, read by the compositions and the audio script)
00.0–02.5  Black. "One app is in front." (Hanken Grotesk 600, 72 px, two tones: first clause grey, second white.)
02.5–05.0  "Everything else is still running." The grey clause holds; a hairline of light draws the notch at top centre.
05.0–08.5  The notch. Clip 02-notch-open: the collapsed notch unfolds into the panel. Line (small, lower left):
           "Coremium lives in your notch."
08.5–14.5  Four choices. Clip 03-apps-row: zoom on the Apps list. The Boost, Normal, Yield and Eco chips sit in
           one row, and the outlined chip moves. Line: "Four choices for every app." Sub: "Your choice always wins."
14.5–19.0  The decision. Clip 04-decision: the status line reads what changed and why, in its real words. Put a
           subtle highlight on that line only (no added text). Line: "It says what it changed, and why."
19.0–25.0  The switch. Clip 05-window-switch. The window button (macwindow icon) is pressed. Motion: the notch
           panel folds into the notch while the window grows from the same top-centre point (one shared-element
           motion, no crossfade). Line: "Or open it as a window." Sub: "The same engine, in a normal window."
25.0–31.0  Live graphs. Clip 06-graphs-2min: the left column of the window. CPU heat strip and line, GPU, Memory.
           Line: "Two minutes of live graphs." Sub: "Measured on this Mac. Kept in memory. Never saved."
31.0–36.0  Advanced. Clip 07-advanced: the Numbers card and per-core values. Line: "Turn on the numbers." Sub: "Per-core
           load, memory, swap and pressure. Off by default."
36.0–40.0  One switch. Clip 08-settings-window-mode: the "Window mode" row turns on; the Dock icon appears (show the
           Dock in frame for two beats). Line: "Notch or window. One switch, remembered."
40.0–45.0  End card on black. Logo (128 px), then "Give the app you're using more room to work." (34 px, grey),
           then "Free. Open source. No account." and github.com/Cubinghackerz/Coremium in mono. Last line in
           small type: "Not affiliated with Apple." Hold 3 s, then fade to black from 44.2.

Storage (09-storage-review) is optional. Use it only if the clip shows nothing personal and the review sheet reads
"Everything goes to the Trash. Nothing is deleted until you empty it." (verify the exact wording in the source first).

FORMATS
- Master: 1920×1080, 60 fps, 16:9. Also a 3840×2160 render if the machine renders it in reasonable time; ask first.
- Vertical: 15 s, 1080×1920, its own composition, not a crop of the master. Notch at the top third. Beats: notch open,
  four choices, the switch, end card.
- Cut-down: 6 s, 1080×1080. The switch beat plus the end card.
- Poster: the frame at 22.0 s (the switch mid-fold).
- captions.srt: every on-screen line with its timing.

STYLE
- Background: pure black #000. Type: Hanken Grotesk 500 and 600 (OFL, the font the site uses). Download once into
  film/fonts and load with @font-face. Never a system font.
- Colours: the app's own: performance-core blue #7DCCF7, efficiency mint #8CE0BF, Boost amber #F5BD6B, GPU violet
  #C4B5FD, dim text white 55%. Use colour only where the app itself uses it.
- Motion: ease-out for reveals (expo.out), ease-in-out for travel (power3.inOut). Entrances 0.4–0.6 s, exits 0.2–0.3 s.
  No UI move faster than 0.4 s. Never more than one big move at a time. Cut on beats. No whip-pans, glitches, lens
  flares, particle clouds or HUD clutter.
- The notch-to-window switch (beat 05) is the signature shot. Everything else in the film supports it.
- Sound: original, synthesized in scripts/score.py (numpy only, no samples, no AI music, no copyrighted music). A
  single soft pulse on each click, a low pad that resolves on the title, one clean sub hit on the end card.
  Loudness -14 LUFS integrated, -1 dBTP true peak.

HARD RULES (a violation fails QA)
- No FPS, battery, temperature, watts, energy, "X% faster" or benchmark claims. No overhead figure in frame.
- No Apple logo as Coremium branding. The chip die in the app draws Apple's system mark (ChipView.swift), and the
  README says so. In this film, crop the chip out of close-ups, or frame it so the mark is not the hero. Do not
  recolour, retouch or redraw it. Flag it in CHECKLIST.md as a decision for me.
- No third-party logos as hero. No real names of people. No account names, file paths or personal file names in frame.
- No stock footage, AI-generated footage, voice clone or copyrighted music.
- Never upload, publish, post, push, or write to the Coremium repo. Work in ./film.
- Never quit or restart Coremium without a clear reason in CHECKLIST.md. Use the menu item or the URL scheme, not kill.

QA GATES (run all; fix and repeat until clean)
1. Lint/validate the HyperFrames project if you used HyperFrames (see launch-film-hyperframes-prompt.md for the skills).
2. Contact sheet: one frame per beat and the first and last frame of each cut. Inspect for clipped text, serif
   fallbacks, banding, off-palette colour, a visible overhead figure, an Apple mark as the hero, and personal data.
3. Claims audit: every on-screen line in captions.srt is matched to its source (README line or Swift string or a
   visible label) in CHECKLIST.md. Any line without a source is removed.
4. Settle audit: for each clip, confirm from the raw file that the first 5 seconds after the open are not in the cut.
5. Side by side: the window's CPU card against the site screenshot web/public/screens/window-*.png (if present).
   Spacing and labels must match.
6. Determinism: render 5 seconds twice; compare frames (ffmpeg framemd5). Any difference fails.
7. Final checks: ffprobe each file (duration, resolution, fps, audio stream). Loudness with ffmpeg ebur128. Captions
   timing within one frame of their cue.
8. Report: files, runtimes, which clips were used, which were cut, the state of Advanced and Window mode in each clip,
   and anything I should approve (the Apple mark on the chip, the demo app names, the 4K render).

DELIVERABLES (./film/out)
- coremium-two-ways-in-1080p60.mp4
- coremium-two-ways-in-vertical-15s.mp4
- coremium-two-ways-in-square-6s.mp4
- poster.png, captions.srt, CHECKLIST.md
```

## Tips
- Start in plan mode so the beats and the claims are checked before any CPU-heavy recording.
- Recording and rendering load the CPU. Record the demo with the window closed and nothing else heavy running, then render later.
- Review the contact sheet first, then give changes per beat. Every time lives in `film/timeline.json`.
