# Coremium 2.0 launch film: the prompt

Goal: a 60 s launch film in the class of Diffusion Studio's, Linear's and Arc's launch reels.
- **Look:** a black void with a planet-edge horizon, and the real product UI moving through 3D space with depth of
  field and motion blur.
- **Type and sound:** tight kinetic type, and sound design that lands on every cut.
- **How it's built:** everything is code (Remotion + React, plus a numpy-synthesized score), so every frame is exact,
  editable and honest.

Paste the block below into Claude Code, started in any folder.

```
ROLE
You are a motion-design director and a senior TypeScript engineer in one. Build and render the Coremium 2.0 launch film
entirely from code. The bar is indistinguishable in polish from a top product launch reel (Diffusion Studio, Linear,
Arc, Raycast). Make every creative decision yourself and do not ask me design questions. Ask only before installing
anything with brew, or before anything outward-facing (upload, post, push). Work until every QA gate passes.

DIRECTOR'S NOTES (the taste bar; reread before each beat)
- The product is the hero. Real UI, shot like a physical object: lit, in depth, in focus, moving with weight.
- One idea per shot. A shot either asks a question or answers it. Nothing decorative earns screen time.
- Contrast of scale: a huge headline, then a tiny exact detail (one chip lighting up). Cut between them on the beat.
- Sound leads picture by 2 frames on reveals. Silence before the title hit is a design element.
- Restraint with colour: the world is black and white. Colour appears only when it means something, and the
  audience must feel it the moment it does.
- Every move eases. Nothing pops on and nothing moves linearly, except grain.
- No stock-video tropes: no particles for their own sake, no lens flares, no glitch, no "tech" HUD clutter, no fake code
  rain.

STEP 0 — SET UP (do this yourself, first)
mkdir -p /Users/nirneet/Movies/coremium-2-film && cd /Users/nirneet/Movies/coremium-2-film
If the folder has files, move them into ./_old and start clean. Work only in this folder.
- Scaffold Remotion (npx create-video@latest --blank, TypeScript) here.
- Add @remotion/google-fonts, @remotion/motion-blur, @remotion/three, @react-three/fiber, three and @remotion/media-utils.
- Remotion is free for individuals and companies of up to 3 people; record that in CHECKLIST.md.
- Audio: Python 3 with numpy only. ffmpeg and ffprobe are at /opt/homebrew/bin.
- Clone github.com/Leonxlnx/claude-launchvideo into ./reference/claude-launchvideo. Read its README, timeline, audio and
  render scripts before running anything. Copy only techniques you understand: timeline-driven audio/picture sync and
  sub-frame motion blur.

SOURCE OF TRUTH (read-only; never write there): /Users/nirneet/Documents/GitHub/Coremium
- README.md is the ONLY place claims may come from.
- Sources/Coremium/Shared/Theme.swift: colours.
- Sources/Coremium/Notch/NotchViews.swift and Notch/Tabs/*.swift: layout and exact labels.
- Sources/Coremium/Chip/ChipView.swift: the chip die and core tiles.
- Sources/Coremium/Engine/AppEngine.swift: decision wording (search "mode activated", "moved to").
- Sources/CoremiumCore/UsageStats.swift: report wording (SessionReport.summary).
- docs/assets/logo.png: the logo.
- web/src/components: brand voice.
PIXEL REFERENCE: render the real UI yourself. From the repo run:
  scripts/render-previews.sh /Users/nirneet/Movies/coremium-2-film/reference/ui
This writes 2x PNGs of every tab (normal and Advanced), the collapsed pill and onboarding, from the real SwiftUI code.
Study them for exact spacing, sizes, weights, radii and copy, and match your React recreations to them. They are
reference only and must NEVER appear in frame:
- They contain Apple's chip symbol and real third-party app names and icons.
- Toggles render as yellow placeholders.
- The Apps tab renders dimmed (a renderer quirk).
Do not use web/public/coremium-panel.png either; it is an old build.

PRODUCT TRUTH (the only claims allowed, worded plainly)
Coremium is a free, open-source Mac app that lives in the notch. While you play, render, code or run a local model, it
moves background apps to the efficiency cores. The app in front stays smooth, and nothing is closed.
2.0 adds:
- an Automatic mode that adapts to real CPU pressure
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
- No FPS, battery-life, temperature, "X% faster" or benchmark claims, and no invented statistics in headlines. Numbers
  inside the recreated UI are illustrative and must look like the real UI. A small "Illustrated recreation" tag (Inter
  500, 18 px, white 40%, bottom right) shows whenever recreated UI is on screen.
- No Apple logo and no Apple product imagery. The chip is a neutral rounded die with pins and no mark.
- No third-party logos or names. Apps are neutral rounded squares in muted solid colours, named "Game", "Browser",
  "Chat", "Music", "Editor", "Terminal".
- Never upload, publish, post or git push. Never write to the Coremium repo.
- Fonts: bundle Inter Tight 500/600 (headlines) and Inter 500/600 (UI) via @remotion/google-fonts. Never rely on
  system fonts (ui-rounded, -apple-system, SF Pro): headless Chrome falls back to a serif.

THE REAL UI, AS IT IS NOW (recreate exactly, in React)
- Collapsed: the notch looks untouched. During a session, its "ears" show a 5-bar performance-core meter on the left
  and an apps-moved count on the right.
- Expanded panel, 780×488 pt, hanging from the notch. Bottom corners have radius 34, background #0A0B14.
- Left column: the chip die with pins, with a soft green glow while protecting. Under it, "LIVE CORE LOAD" with P and E
  tile rows: tiles are white at intensity, amber above 85%. Then spec lines: 5P + 6E cores, 14-core GPU, 18 GB,
  Plugged in, Cool.
- Right column, top to bottom:
  1. Mode pills: the selected one is white with black text and reads "Automatic · Gaming"; the others (Balanced,
     Gaming, Creator, Coding, Local AI) are dark circles with icons.
  2. A right-aligned row: "# Advanced" capsule and a chevron-up Hide button.
  3. Status line, with a green dot: "Protecting Game · 12 background processes at lower priority".
  4. A tab bar inside one dark rounded container: Apps, Insights, Storage, System, Simulate, Guide, Settings. The
     selected tab is a white pill with black text. These are names only, no icons.
  5. Tab content.
- Apps rows: icon, name, kind line ("Protected", "Steps aside during boosts", "Always on efficiency cores"), an outcome
  word (Heavy / Moderate / Background), then Boost / Normal / Yield / Eco chips. The active chip is outlined in its
  colour (Boost amber, Yield sky); Eco is filled mint.
- Proof strip at the bottom: a checkmark badge, "Today: a boost ran for 42 min", a grey second line, and a white
  "Details" pill.
- Colours:
  - background #0A0B14; card white 5.5%; hairline white 9%; dim text white 55%
  - good #73DB9E: active / protected
  - boost #F5BD6B: Boost, hot cores
  - yield #7DCCF7: Yield, performance cores
  - eco #8CE0BF: Eco, efficiency cores
  - gpu #C4B5FD: GPU
- UI type: Inter 500/600 at the real sizes ×2 (the app uses SF Rounded at 10.5–13 pt), monospaced digits.

WORLD AND LOOK (src/tokens.ts; nothing outside it)
- Background is pure #000.
- The horizon is a planet edge rising from below frame, drawn in a full-frame WebGL shader:
  - a circle of radius 2.6 × frame height, centred below frame
  - a thin bright rim: cyan #7DCCF7 at the centre fading to indigo #6152E0 at the sides
  - a faint atmosphere above the rim and a soft inner glow below it
  - ±0.5/255 dither so gradients never band
- Film grain: animated at 24 fps, 3–4% overlay. Vignette 18%.
- Panels: a 1 px top-edge inner highlight (white 14%) and a two-layer shadow (0 30 80 #000 60%; 0 2 6 #000 40%).
  Render UI at 2x for crisp 4K.
- Headlines: Inter Tight 600, 96 px at 1080p, tracking -0.045em, line-height 1.0, never more than 7 words on screen.
  Use two tones: the first clause in #71717A, the second in #FFFFFF. Optical centre is 46% height.

MOTION SYSTEM (src/motion.ts)
- Curves:
  - spring (mass 1, stiffness 120, damping 20) for UI
  - expo-out cubic-bezier(0.16,1,0.3,1) for camera and reveals
  - inOut (0.7,0,0.3,1) for travel
  - exit (1,0.02,0.54,0.42)
- Timing: entrances 400–600 ms, exits 200–300 ms, sibling stagger 3 frames. Opacity finishes before position settles.
  Every hold keeps a 2–3% drift or a live counter.
- Camera: a CSS 3D <Camera> (perspective 1800px) with planes at -600 (horizon), 0 (UI) and +250 (foreground type).
  Moves:
  - dolly
  - orbit up to 10°
  - rack focus: off-focus planes get blur 0→14 px and brightness 0.7
  - parallax
  Only one big move at a time.
- Motion blur: <CameraMotionBlur> on every fast move. Use 16 samples and a 180° shutter on masters, 4 on previews.
- Signature transition, "the unfold": the notch pill (black, 200×34, radius 17) springs open into the panel.
  1. Width, height and radius ride one spring.
  2. A specular sweep crosses the top edge (white 25%, 600 ms).
  3. Contents rise with a 3-frame stagger from 70% open.
  The reverse is "the fold". Use the unfold exactly three times.

STRUCTURE (60.0 s at 60 fps; every beat and every sound cue lives in src/timeline.ts, which audio and picture both import)
00.0–02.0 Hook. Black. One white line types and cuts on the beat: "Everything you run fights for the same cores."
          A hard cut to black.
02.0–06.0 Grain only. The horizon rises 120 px (expo-out). At 4.6 a hairline of light draws the notch pill at top
          centre. A sub-bass swell plays.
06.0–10.0 Headline with a per-word mask reveal: "Your Mac runs everything" / "on the same fast cores." The second line
          lands on the beat at 08.2. Dolly 3%.
10.0–17.0 The problem.
          - Eleven core blocks float in 3D at a 20° tilt: 5 "Performance" (sky outline) over 6 "Efficiency" (mint
            outline).
          - App tokens fly in from the frame edges with motion blur: Game, Browser, Chat, Music, then 12 tiny grey
            helper dots. All pile onto the performance row.
          - Those blocks heat from sky to amber, with a 2 Hz flicker at 6% amplitude. Efficiency blocks stay dim.
          - The pad rises in tension.
17.0–23.0 Unfold #1. The notch opens into the full panel on the Apps tab (the layout above). Camera dolly-in 0.86→1.0.
          At 20.5, rack focus to the foreground title "Coremium 2.0" (Inter Tight 600, 140 px). It holds 1.6 s, then
          racks back.
23.0–30.0 The decision.
          - The Game row's chip flips to Boost (amber outline) and the mode pill reads "Automatic · Gaming".
          - A decision line types at 38 chars/s:
            "Gaming mode activated. Game became active. Browser and Chat moved to Yield, Music to Eco."
          - Each chip lights on its word with a click.
          - Picture-in-picture: tokens glide from the performance blocks to the efficiency blocks on inOut curves,
            staggered 4 frames. The performance blocks cool from amber to calm sky; efficiency tiles fill mint.
          - The pad resolves from minor to major.
30.0–42.0 Montage: six 2.0 s shots. Each has its own camera move and a 3–5 word two-tone line, lower-left. The tab bar
          slides to each tab with the white pill travelling.
          1. Adaptive Automatic: the P-tiles climb amber, hold, and one busy app steps aside.
             Line: "Adapts to real pressure." Camera: push-in.
          2. System › Memory: a pressure bar, swap and top apps with "Hide" / "Quit…".
             Line: "Find what's eating memory." Camera: slide from left.
          3. Storage: the ring draws its segments clockwise, then the review sheet slides up with "Move 6.4 GB to the
             Trash?" and "Everything goes to the Trash. Nothing is deleted until you empty it."
             Line: "Clear space. Review first." Camera: tilt-up.
          4. Rules per game: the scope switch "Everyone / Game only" slides, and a chip changes only in game scope.
             Line: "Rules for every game." Camera: orbit 8°.
          5. A report card drops out of the notch on a spring: "Game · 42 min · up to 23 background processes moved
             aside · memory stayed normal". Line: "See what changed." Camera: drop-follow.
          6. A minimal terminal types `open coremium://mode/gaming`, and the mode pill switches.
             Line: "Automate it." Camera: whip-pan in with motion blur.
          Cut on beats with whip transitions and blur; never use crossfades.
42.0–50.0 Fold.
          - The panel folds into the notch. The ears come alive: a breathing 5-bar meter left, "12" right.
          - Behind it, an abstract "game" plays: a slow flowing colour field in a shader. No real game.
          - At 44.5 a decision toast drops from the notch, "Gaming mode activated · Browser and Chat moved to Yield".
            It holds 1.8 s and retracts.
          - Line: "Nothing closed." / "What matters stays smooth."
50.0–60.0 End card on the horizon.
          - Logo (128 px) with soft bloom, then "Coremium 2.0".
          - "Keep what matters smooth, without closing anything." in 34 px grey.
          - "Free. Open source. No account."
          - github.com/Cubinghackerz/Coremium in mono, 26 px.
          - Silence for 8 frames, then the final hit at 52.0, a long reverb tail, and a fade to black from 58.8.

SOUND (scripts/score.py; numpy only, no samples, no copyrighted music)
- Tempo: 92 BPM, with the grid locked to timeline.ts.
- Layers:
  - sub-bass swells
  - filtered-noise risers that end exactly on reveals
  - UI clicks: 3 ms filtered transients, ±8% pitch variation
  - a warm detuned-saw pad, low-passed, resolving from minor to major at 25.0
  - a soft FM bell on the report card
  - whooshes on whip-pans
  - one wide final hit with a numpy-built exponential-decay impulse-response reverb
- Mixing:
  - Sidechain the pad under clicks. Sound leads picture by 2 frames on reveals.
  - Normalise to -14 LUFS integrated, -1 dBTP true peak. Measure with ffmpeg ebur128 and adjust until within 0.5 LU.
- scripts/verify_sync.py fails if any cue is more than one frame from its visual event.

DELIVERABLES (./out)
- coremium-2-launch-4k60.mp4: 3840×2160, 60 fps, H.264 High, CRF 14 or 40 Mbps, AAC 320k
- coremium-2-launch-1080p60.mp4
- coremium-2-30s.mp4: 00–02, then 17–30, then 50–60, re-timed so the cuts land on beats
- coremium-2-9x16.mp4: 15 s, 1080×1920, with its own layout. Not a crop: the notch in the top third; hook, unfold,
  decision, report card, end card.
- poster.png: the frame at 21.0
- captions.srt: the on-screen lines
- CHECKLIST.md:
  - every on-screen line, mapped to the README sentence or source file that backs it
  - font licences (OFL) and the Remotion licence note
  - "all audio synthesized in scripts/score.py"
  - a confirmation of each hard rule

QA GATES (do all of them; fix and repeat until clean; then stop)
1. Render a 1080p preview with 4 blur samples. Export a contact sheet: one frame per beat plus the first and last frame
   of every transition.
2. Inspect every frame for:
   - clipped, overlapping or widowed text
   - labels that differ from the Swift sources and the reference/ui renders
   - banding
   - off-palette colour
   - any logo, brand or claim the hard rules forbid
   - UI that would not exist in the real app
   - serif fallback fonts
3. Side by side: put your recreated panel next to reference/ui/notch-apps.png at the same scale. Spacing, sizes and
   copy must match.
4. Motion audit:
   - no UI move faster than 0.4 s
   - no two big moves at once
   - every cut on a beat
   - nothing perfectly still for more than 1.2 s
5. Fix everything in one pass and re-check the changed beats.
6. Render the masters with 16 blur samples. ffprobe each file (duration, resolution, fps, audio stream). Run
   verify_sync.py and the loudness check.
7. Report: files, runtimes, what is recreated, and anything I should approve.
```

## Tips
- Review the 1080p preview first, then give changes per beat ("slow 17–23 by 15%", "softer clicks"). Everything lives in
  `src/timeline.ts`.
- For extra authenticity, add two or three real notch screen recordings (Shift+Command+5) as cut-ins, but only from a
  setup where no third-party app icons or the Apple chip symbol are visible.
