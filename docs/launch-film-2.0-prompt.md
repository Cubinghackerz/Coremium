# Coremium 2.0 launch film: the prompt

Goal: a 60 s launch film at the level of Diffusion Studio's, Linear's and Arc's reels. The look is a black void and a planet-edge
horizon, with real product UI moving through 3D space under depth of field and motion blur. Type is tight and the score lands on every cut.
Everything is built from code (Remotion + React, plus a numpy-synthesized score), so every frame is exact, editable and honest.

Paste the block below into Claude Code (or Codex), started in any folder.

```
ROLE
You are a motion-design director and a senior TypeScript engineer in one. You will build the Coremium 2.0 launch film
entirely from code and render it. Bar: indistinguishable in polish from a top product launch reel (Diffusion Studio,
Linear, Arc, Raycast). Decide everything yourself; do not ask me design questions. Work until the QA gates pass.

STEP 0 — SET UP (do this yourself, first)
mkdir -p /Users/nirneet/Movies/coremium-2-film && cd /Users/nirneet/Movies/coremium-2-film
If the folder already has files, move them into ./_old and start clean. Work only in this folder.
Scaffold Remotion (npx create-video@latest --blank, TypeScript) into it. Remotion is free for individuals and companies of
up to 3 people; note this in CHECKLIST.md. Add: @remotion/google-fonts, @remotion/motion-blur, @remotion/three,
@react-three/fiber, three, @remotion/media-utils. Use Python 3 with numpy only for audio; ffmpeg/ffprobe are at /opt/homebrew/bin.
Clone github.com/Leonxlnx/claude-launchvideo into ./reference. Read its README, timeline, audio and render scripts before
running anything, and copy only techniques you understand: timeline-driven sync and sub-frame motion blur.

SOURCE OF TRUTH (read-only, never write there): /Users/nirneet/Documents/GitHub/Coremium
- README.md: the only place claims may come from.
- Sources/Coremium/Shared/Theme.swift: colours.
- Sources/Coremium/Notch/NotchViews.swift, Notch/Tabs/*.swift, Chip/ChipView.swift: layout and exact labels.
- Sources/Coremium/Engine/AppEngine.swift (search "mode activated", "moved to"): decision wording.
- Sources/CoremiumCore/UsageStats.swift (SessionReport.summary): report wording.
- docs/assets/logo.png: the logo.
- web/src/components: brand voice.
Do NOT use web/public/coremium-panel.png. It is an old build showing an Apple logo and third-party app icons.

PRODUCT TRUTH (the only claims allowed, worded plainly)
Coremium is a free, open-source Mac app that lives in the notch. While you play, render, code or run a local model, it moves
background apps to the efficiency cores. The app in front stays smooth, and nothing is closed.
2.0 adds:
- a memory and swap guard
- startup helpers you can switch off
- session report cards
- rules per game
- battery-aware moves
- automation: links, Terminal, Shortcuts
- in-app updates
- a live core meter in the notch, with decisions that drop out of it
- a Storage ring with review-before-Trash
Tagline: "Keep what matters smooth, without closing anything."

HARD RULES (a violation fails QA)
- No FPS, battery-life, temperature, "X% faster" or benchmark claims. No invented statistics in headlines. Numbers inside the
  recreated UI are illustrative and must look like the real UI. A small "Illustrated recreation" tag (Inter 500, 18 px,
  white 40%, bottom right) shows whenever recreated UI is on screen.
- No Apple logo or Apple product imagery. Draw the chip as a neutral rounded die with pins, labelled "Apple silicon" in small
  grey text or not at all.
- No third-party logos or names. Apps are neutral rounded squares in muted solid colours, named "Game", "Browser", "Chat",
  "Music", "Editor", "Terminal".
- Never upload, publish, post or git push. Never touch the Coremium repo.
- Fonts: bundle via @remotion/google-fonts. Use Inter Tight 500/600 for headlines and Inter 500/600 for UI. Never rely on
  system fonts (ui-rounded, -apple-system, SF Pro), because they fall back to a serif in headless Chrome.

DESIGN SYSTEM (src/tokens.ts; nothing outside it)
- World: #000.
- The horizon is a planet edge rising from below frame. Draw it in a full-frame <canvas> or WebGL shader: a circle of radius
  2.6 × frame height, centred below frame. It has a thin bright rim (cyan #7DCCF7 at the centre, fading to indigo #6152E0 at
  the sides), a faint atmosphere above the rim and a soft inner glow below it. Add ±0.5/255 dither so gradients never band.
- Film grain: animated at 24 fps, 3–4% overlay, generated in a shader or from a pre-rendered noise tile set.
- Vignette: 18%, multiply.
- UI is mostly monochrome:
  - panel #0A0B14 at 92%
  - card white 5.5%
  - hairline white 9%
  - dim text white 55%
- Colour appears only where it means something:
  - green #73DB9E: active or protected
  - amber #F5BD6B: Boost, and hot performance cores
  - sky #7DCCF7: Yield, and the performance cores
  - mint #8CE0BF: Eco, and the efficiency cores
  - violet #C4B5FD: GPU
- Panels have a 30 px radius, a 1 px top-edge inner highlight (white 14%) and a two-layer shadow (0 30 80 #000 60% and
  0 2 6 #000 40%). Render UI at 2x device scale for crisp edges at 4K.
- Headlines: Inter Tight 600, 96 px at 1080p, tracking -0.045em, line-height 1.0. Use two tones: the first clause in #71717A,
  the second in #FFFFFF. Never more than 7 words on screen. Optical centre is 46% height.

MOTION SYSTEM (src/motion.ts)
- Curves: spring (mass 1, stiffness 120, damping 20) for UI. Expo-out cubic-bezier(0.16,1,0.3,1) for camera and reveals.
  inOut (0.7,0,0.3,1) for travel. Exit (1,0.02,0.54,0.42) for exits. No linear motion except grain and horizon drift.
- Timing: entrances 400–600 ms, exits 200–300 ms, sibling stagger 3 frames at 60 fps-equivalent. Opacity finishes before
  position settles. Keep something moving in every hold, such as a slow 2–3% dolly, a counter or light drift.
- Camera: one <Camera> wrapper holds CSS 3D (perspective 1800px) with planes at depths -600 (horizon), 0 (panel) and
  +250 (foreground type). Moves:
  - dolly-in
  - slow orbit up to 10°
  - rack focus: unfocused planes get blur(0→14px) and brightness 0.7
  - parallax between all three planes
  Only one big move at a time.
- Motion blur: wrap fast moves in <CameraMotionBlur>. Use 16 samples and shutter 180° on masters, 4 samples on previews.
- Signature transition, "the unfold": the notch pill (black, 200×34, r 17) springs open into the Coremium panel.
  1. Width, height and radius interpolate on one spring.
  2. A specular sweep crosses the top edge (white 25%, 600 ms).
  3. Contents fade up with a 3-frame stagger once it reaches 70% open.
  The reverse plays as "the fold". Use the unfold exactly three times.

STRUCTURE (60.0 s at 60 fps; every beat and every sound cue lives in src/timeline.ts, which audio and picture both import)
00.0–05.0 Cold open. Black, grain only. At 1.0 the horizon rises 120 px with expo-out over 3 s. At 3.2 a hairline of light
          draws the notch pill at top centre. A sub-bass swell starts at 0.0.
05.0–10.0 Headline with a per-word mask reveal: "Your Mac runs everything" / "on the same fast cores." The second line lands
          on the beat at 07.6. Dolly 3%.
10.0–17.0 The problem.
          - Eleven core blocks float in 3D at a 20° tilt, in two rows: 5 performance cores labelled "Performance" (sky
            outline) and 6 efficiency cores labelled "Efficiency" (mint outline).
          - App tokens arrive from frame edges with motion blur and pile onto the performance row: Game first, then Browser,
            Chat and Music, plus 12 small grey "helper" dots.
          - Performance blocks heat from sky to amber, with a 2 Hz flicker at 6% amplitude. Efficiency blocks stay dim.
          - The pad gains tension.
17.0–23.0 Unfold #1. The notch opens into the full panel.
          - Recreate the System panel from NotchViews.swift:
            - left: the chip die, with "LIVE CORE LOAD" and P and E tile rows
            - right: the mode bar (Automatic, Balanced, Gaming, Creator, Coding, Local AI)
            - a status line, tabs, and Running/Installed
            - five app rows with Boost / Normal / Yield / Eco chips
            - the proof strip
          - Camera dolly-in from 0.86 to 1.0.
          - At 20.5, rack focus to the foreground title "Coremium 2.0" (Inter Tight 600, 140 px, white). It holds for 1.6 s,
            then focus racks back.
23.0–30.0 The decision.
          - The Game row's dot turns green. The mode title reads "Automatic · Gaming".
          - The decision line types at 38 chars/s with a soft cursor:
            "Gaming mode activated. Game became active. Browser and Chat moved to Yield, Music to Eco."
          - Each chip lights on its word, in its colour, with a click.
          - In a picture-in-picture plane, tokens glide from the performance blocks to the efficiency blocks on inOut curves,
            staggered 4 frames. The performance blocks cool from amber back to calm sky; efficiency tiles fill mint.
          - The pad resolves from minor to major.
30.0–42.0 Montage: six 2.0 s shots. Each has its own camera move and one 3–5 word line, lower-left, two-tone.
          1. Memory guard: a memory card with a pressure bar, swap and top apps with "Hide" / "Quit…".
             Line: "Find what's eating memory." Camera: slide-in from left.
          2. Startup: a helper list, with two toggles flipping off. Line: "Quiet what starts with your Mac." Camera: tilt-up.
          3. Storage: the ring draws its segments clockwise, then the review sheet slides up with "Move 6.4 GB to the Trash?" and
             "Everything goes to the Trash. Nothing is deleted until you empty it."
             Line: "Clear space. Review first." Camera: push-in.
          4. Per-game rules: the scope switch "Everyone / Game only" slides; a chip changes only in the game scope.
             Line: "Rules for every game." Camera: orbit 8°.
          5. Report card: the card drops out of the notch on a spring. Text: "Game · 42 min · up to 23 background processes moved aside ·
             memory stayed normal". Line: "See what changed." Camera: drop-follow.
          6. Automation: a minimal terminal types `open coremium://mode/gaming` and the mode pill switches.
             Line: "Automate it." Camera: whip-pan in, with motion blur.
          Cut on beats: whip transitions with blur, never crossfades.
42.0–50.0 Fold.
          - The panel folds back into the notch.
          - The notch ears come alive: on the left, a 5-bar P-core meter breathing; on the right, a moved-apps count "12".
          - Behind it, an abstract "game" plays: a slow flowing colour field in a shader. No real game.
          - At 44.5 a decision toast drops from the notch: "Gaming mode activated · Browser and Chat moved to Yield". It holds
            1.8 s and retracts.
          - Line: "Nothing closed." / "What matters stays smooth."
50.0–60.0 End card on the horizon.
          - Logo (docs/assets/logo.png, 128 px) with a soft bloom.
          - "Coremium 2.0", then "Keep what matters smooth, without closing anything." in 34 px grey.
          - "Free. Open source. No account."
          - github.com/Cubinghackerz/Coremium in mono, 26 px.
          - Final hit at 52.0, a long reverb tail, and a fade to black from 58.8.

SOUND (scripts/score.py; numpy only, no samples, no copyrighted music)
- Tempo: 92 BPM, with the grid locked to the timeline.
- Layers:
  - a sub-bass swell
  - filtered-noise risers that end exactly on each reveal
  - UI clicks: 3 ms filtered transients, varied ±8% in pitch
  - a warm detuned-saw pad, low-passed, that resolves from minor to major at 25.0
  - a soft FM bell on the report card
  - whooshes on the whip-pans
  - one wide final hit with an exponential-decay convolution reverb (build the impulse response in numpy)
- Mixing: sidechain-duck the pad under clicks. Normalise to -14 LUFS integrated with -1 dBTP true peak. Measure with
  ffmpeg ebur128 and adjust until it matches within 0.5 LU.
- scripts/verify_sync.py fails if any cue is more than one frame from its visual event in timeline.ts.

DELIVERABLES (./out)
- coremium-2-launch-4k60.mp4: 3840×2160, 60 fps, H.264 High, CRF 14 or 40 Mbps, AAC 320k
- coremium-2-launch-1080p60.mp4
- coremium-2-30s.mp4: 05–30 plus 50–60
- coremium-2-9x16.mp4: 15 s, 1080×1920, with its own layout (the notch in the top third; unfold, decision, report card, end
  card). Not a crop.
- poster.png: the frame at 21.0
- captions.srt: the on-screen lines
- CHECKLIST.md:
  - every on-screen line, mapped to the README sentence or source file that backs it
  - font licences (OFL) and the Remotion licence note
  - "all audio synthesized in scripts/score.py"
  - a confirmation of each hard rule

QA GATES (do all of them, fix, repeat until clean, then stop)
1. Render a 1080p preview with 4 blur samples. Export a contact sheet of one frame per beat (16 frames) plus the first and
   last frame of every transition.
2. Inspect every frame for:
   - clipped, overlapping or widowed text
   - labels that differ from the Swift sources
   - banding
   - off-palette colour
   - any logo, brand or claim the hard rules forbid
   - UI that would not exist in the real app
   - serif fallback fonts
3. Motion audit:
   - no UI move faster than 0.4 s
   - no two big moves at once
   - every cut on a beat
   - nothing sits perfectly still for more than 1.2 s
4. Fix everything in one pass and re-check the changed beats.
5. Render masters with 16 blur samples. ffprobe each file (duration, resolution, fps, audio stream). Run verify_sync.py and
   the loudness check.
6. Ask before installing anything with brew. Finish with a short report: files, runtimes, what is recreated, anything I
   should approve.
```

## Tips
- Review the 1080p preview first, then give changes per beat ("slow 17–23 by 15%", "softer clicks"). Everything lives in
  `src/timeline.ts`.
- For extra authenticity, drop in two or three real notch screen recordings (Shift+Command+5) as cut-ins, but only from a
  build where no third-party app icons are visible.
