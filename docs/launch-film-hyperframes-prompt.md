# Coremium launch film with HyperFrames: the prompt

HyperFrames (HeyGen, open source) renders plain HTML + CSS + GSAP into video, deterministically, frame by frame in
headless Chrome. It ships agent skills, including `/product-launch-video`. This prompt has Claude build a 60 s
Coremium 2.0 launch film at the level of the best product reels (Diffusion Studio, Linear, Arc), as HTML compositions.

Paste the block below into Claude Code, started in any folder.

```
ROLE
You are a motion-design director and a senior front-end engineer in one. Build and render the Coremium 2.0 launch
film with HyperFrames. The bar is indistinguishable in polish from a top product launch reel (Diffusion Studio,
Linear, Arc, Raycast). Make every creative decision yourself; do not ask me design questions. Ask only before
installing anything with brew, or before anything outward-facing (upload, post, push). Work until every QA gate passes.

DIRECTOR'S NOTES (reread before each beat)
- The product is the hero: real UI, shot like a physical object, lit, in depth, moving with weight.
- One idea per shot. A shot either asks a question or answers it. Nothing decorative earns screen time.
- Contrast of scale: a huge headline, then one tiny exact detail (a single chip lighting up). Cut on the beat.
- Sound leads picture by 2 frames on reveals. Silence before the title hit is a design element.
- The world is black and white. Colour appears only when it means something, and the viewer must feel it.
- Every move eases. Nothing pops on, nothing moves linearly except grain.
- No stock-video tropes: no particles for their own sake, no lens flares, no glitch, no HUD clutter, no fake code rain.

STEP 0 — SET UP (do this yourself, first)
1. mkdir -p /Users/nirneet/Movies/coremium-hyperframes && cd /Users/nirneet/Movies/coremium-hyperframes
   If the folder has files, move them into ./_old first. Work only in this folder.
2. Check `node -v` (needs 22 or newer) and `ffmpeg -version` (it is at /opt/homebrew/bin). Ask me before installing
   anything with brew.
3. npx skills add heygen-com/hyperframes
   Then READ the installed skills before writing any composition: /hyperframes (the router and capability map),
   /hyperframes-core, /hyperframes-animation, /hyperframes-keyframes and /product-launch-video. They describe the
   installed version. Where they differ from this prompt on syntax, flags or file layout, the skills and
   `npx hyperframes --help` win. This prompt decides the story, look and rules.
4. npx hyperframes init film && cd film
   Read what init produced. Browse the block catalog the skills describe, and use a block (`npx hyperframes add <name>`)
   only if it beats writing the shot yourself.
5. HyperFrames rules to follow exactly (confirm each against the skills):
   - The root is <div data-composition-id=... data-width=... data-height=...>. Each element is timed with data-start,
     data-duration and data-track-index. Seekable media uses class="clip".
   - Animate with GSAP. Every timeline is created { paused: true } and registered on window.__timelines under its
     composition id.
   - Rendering must be deterministic: no Math.random() (use a seeded PRNG), no Date.now(), no requestAnimationFrame
     clocks, no infinite repeats.
   - Fonts are local files with @font-face, never a network font at render time.
   - One composition per beat, assembled into the master. Use sub-compositions if the skills support them.

SOURCE OF TRUTH (read-only; never write there): /Users/nirneet/Documents/GitHub/Coremium
- README.md is the ONLY source of claims.
- Sources/Coremium/Shared/Theme.swift: colours.
- Sources/Coremium/Notch/NotchViews.swift and Notch/Tabs/*.swift: layout and exact labels.
- Sources/Coremium/Chip/ChipView.swift: the chip die and core tiles.
- Sources/Coremium/Engine/AppEngine.swift: decision wording (search "mode activated", "moved to").
- Sources/CoremiumCore/UsageStats.swift: report wording (SessionReport.summary).
- docs/assets/logo.png: the logo.
- web/src/components: brand voice.
PIXEL REFERENCE: from the repo, run `scripts/render-previews.sh /Users/nirneet/Movies/coremium-hyperframes/reference/ui`.
This writes 2x PNGs of every tab rendered from the real SwiftUI code. Match your HTML recreations to them for spacing,
sizes, weights, radii and copy. They are reference only and must NEVER appear in frame:
- they contain Apple's chip symbol and real app names and icons
- toggles show as yellow placeholders
- the Apps tab renders dimmed (a renderer quirk)
Do not use web/public/coremium-panel.png either (it is an old build).

PRODUCT TRUTH (the only claims allowed, in plain words)
Coremium is a free, open-source Mac app that lives in the notch. While you play, render, code or run a local model, it
moves background apps to the efficiency cores. The app in front stays smooth, and nothing is closed. 2.0 adds:
- an Automatic mode that adapts to real CPU pressure
- a memory and swap guard
- startup helpers you can switch off
- session report cards
- rules per game
- battery-aware moves
- automation (links, Terminal, Shortcuts)
- in-app updates and Homebrew install
- a live core meter in the notch, with decisions that drop out of it
- a Storage ring with review before anything goes to the Trash
Tagline: "Keep what matters smooth, without closing anything."

HARD RULES (a violation fails QA)
- No FPS, battery-life, temperature, "X% faster" or benchmark claims, and no invented statistics in headlines. Numbers
  inside the recreated UI are illustrative and must look like the real UI.
- A small "Illustrated recreation" tag (Inter 500, 18 px, white 40%, bottom right) shows whenever recreated UI is on
  screen.
- No Apple logo or Apple product imagery. The chip is a neutral rounded die with pins and no mark.
- No third-party logos or names. Apps are neutral rounded squares in muted solid colours, named "Game", "Browser",
  "Chat", "Music", "Editor", "Terminal".
- No AI-generated footage, no stock video, no voice clone. Everything on screen is HTML you wrote.
- Never upload, publish, post or git push. Never write to the Coremium repo.
- Fonts: download Inter Tight 500/600 (headlines) and Inter 500/600 (UI) once from Google Fonts into ./film/fonts (OFL),
  then load them with @font-face. Never use system fonts like SF Pro or -apple-system (renders can fall back to a serif).

THE REAL UI, AS IT IS NOW (recreate exactly, in HTML/CSS)
- Collapsed: the notch looks untouched. During a session its "ears" show a 5-bar performance-core meter on the left and
  an apps-moved count on the right.
- Expanded panel: 780×488 pt, hanging from the notch, bottom corners radius 34, background #0A0B14.
- Left column:
  - the chip die with pins, with a soft green glow while protecting
  - "LIVE CORE LOAD" with P and E tile rows: white at intensity, amber above 85%
  - spec lines: 5P + 6E cores, 14-core GPU, 18 GB, Plugged in, Cool
- Right column, top to bottom:
  1. Mode pills: the selected one is white with black text and reads "Automatic · Gaming"; the others (Balanced, Gaming,
     Creator, Coding, Local AI) are dark circles with icons.
  2. A right-aligned row with a "# Advanced" capsule and a chevron-up Hide button.
  3. The status line, with a green dot: "Protecting Game · 12 background processes at lower priority".
  4. The tab bar in one dark rounded container: Apps, Insights, Storage, System, Simulate, Guide, Settings. The selected
     tab is a white pill with black text. Names only, no icons.
  5. Tab content.
- Apps rows have:
  - icon, name and a kind line ("Protected", "Steps aside during boosts", "Always on efficiency cores")
  - an outcome word (Heavy / Moderate / Background)
  - Boost / Normal / Yield / Eco chips. The active chip is outlined in its colour (Boost amber, Yield sky); Eco is
    filled mint.
- The proof strip at the bottom: a checkmark badge, "Today: a boost ran for 42 min", a grey second line, and a white
  "Details" pill.
- Colours:
  - background #0A0B14; card white 5.5%; hairline white 9%; dim text white 55%
  - good #73DB9E: active, protected
  - boost #F5BD6B: Boost, hot cores
  - yield #7DCCF7: Yield, performance cores
  - eco #8CE0BF: Eco, efficiency cores
  - gpu #C4B5FD: GPU
- UI type: Inter 500/600 at the real sizes ×2, with tabular numbers.

WORLD AND LOOK (put every value in film/tokens.css; use nothing outside it)
- Pure black (#000).
- The horizon is a planet edge rising from below frame, drawn in one <canvas> or WebGL layer driven by the timeline
  (never by its own clock):
  - a circle of radius 2.6 × frame height, centred below frame
  - a thin bright rim: cyan #7DCCF7 at the centre fading to indigo #6152E0 at the sides
  - a faint atmosphere above it and a soft inner glow below
  - ±0.5/255 dither so it never bands
- Film grain at 3–4%: pre-generate 24 seeded noise frames as PNGs and step through them on the timeline (24 fps). No live
  random noise. Vignette 18%.
- Panels: a 1 px top-edge inner highlight (white 14%) and a two-layer shadow (0 30 80 #000 60%; 0 2 6 #000 40%).
- Headlines: Inter Tight 600, 96 px at 1080p, letter-spacing -0.045em, line-height 1.0, never more than 7 words on screen.
  Use two tones: the first clause in #71717A, the second in #FFFFFF. Optical centre is 46% height.

MOTION SYSTEM (film/motion.js; every tween uses these)
- Eases:
  - UI: "expo.out" for reveals, and a spring-like "back.out(1.2)" only for small UI pops
  - travel: "power3.inOut"
  - exits: "power2.in"
  - never "none", except grain stepping
- Timing:
  - entrances 0.4–0.6 s, exits 0.2–0.3 s, sibling stagger 0.05 s
  - opacity finishes before position settles
  - every hold keeps a 2–3% drift or a live counter
- Camera: wrap each shot in a 3D stage (perspective 1800px) with planes at translateZ -600 (horizon), 0 (UI) and
  +250 (foreground type). Moves:
  - dolly (scale or translateZ)
  - orbit up to 10° (rotateY)
  - rack focus: off-focus planes get filter blur 0→14 px and brightness 0.7
  - parallax between planes
  Only one big move at a time.
- Motion blur: for fast moves, use directional blur on the moving layer, scaled to velocity: duplicate trailing copies
  at 15–30% opacity, or an SVG feGaussianBlur with stdDeviation along the travel axis, keyed on the timeline. Render the
  master at 60 fps.
- Signature transition, "the unfold": the notch pill (black, 200×34, radius 17) grows into the panel.
  1. Width, height and border-radius ride one expo.out tween.
  2. A specular sweep crosses the top edge (a white 25% gradient, 0.6 s).
  3. Contents rise with stagger from 70% open.
  The reverse is "the fold". Use the unfold exactly three times.

STRUCTURE (60.0 s; every beat and every sound cue time lives in film/timeline.json, read by both the compositions and
the audio script)
00.0–02.0 Hook. Black. One white line types and cuts on the beat: "Everything you run fights for the same cores."
          Hard cut to black.
02.0–06.0 Grain only. The horizon rises 120 px (expo.out). At 4.6 a hairline of light draws the notch pill at top centre.
          A sub-bass swell plays.
06.0–10.0 Headline with a per-word mask reveal: "Your Mac runs everything" / "on the same fast cores." The second line
          lands on the beat at 08.2. Dolly 3%.
10.0–17.0 The problem.
          - Eleven core blocks float in 3D at a 20° tilt: 5 "Performance" (sky outline) over 6 "Efficiency" (mint
            outline).
          - App tokens fly in from the frame edges with motion blur: Game, Browser, Chat, Music, then 12 tiny grey
            helper dots. All pile onto the performance row.
          - Those blocks heat from sky to amber, with a 2 Hz flicker at 6% amplitude. Efficiency blocks stay dim.
17.0–23.0 Unfold #1. The notch opens into the full panel on the Apps tab. Camera dolly-in 0.86→1.0. At 20.5, rack focus to
          the foreground title "Coremium 2.0" (Inter Tight 600, 140 px). Hold 1.6 s, then rack back.
23.0–30.0 The decision.
          - The Game row's chip flips to Boost (amber outline) and the mode pill reads "Automatic · Gaming".
          - The decision line types at 38 chars/s:
            "Gaming mode activated. Game became active. Browser and Chat moved to Yield, Music to Eco."
          - Each chip lights on its word, with a click.
          - Picture-in-picture: tokens glide from the performance blocks to the efficiency blocks (power3.inOut,
            stagger 0.07 s). The performance blocks cool from amber to calm sky; the efficiency tiles fill mint.
30.0–42.0 Montage: six 2.0 s shots, each with its own camera move and a 3–5 word two-tone line, lower-left. The white tab
          pill slides to each tab.
          1. Adaptive Automatic: the P tiles climb amber, hold, and one busy app steps aside.
             Line: "Adapts to real pressure." Camera: push-in.
          2. System › Memory: pressure bar, swap, and top apps with Hide / Quit….
             Line: "Find what's eating memory." Camera: slide from left.
          3. Storage: the ring draws its segments clockwise, then the review sheet rises with "Move 6.4 GB to the Trash?"
             and "Everything goes to the Trash. Nothing is deleted until you empty it."
             Line: "Clear space. Review first." Camera: tilt-up.
          4. Rules per game: the scope switch "Everyone / Game only" slides, and one chip changes only in game scope.
             Line: "Rules for every game." Camera: orbit 8°.
          5. A report card drops out of the notch: "Game · 42 min · up to 23 background processes moved aside · memory
             stayed normal". Line: "See what changed." Camera: drop-follow.
          6. A minimal terminal types `brew install --cask cubinghackerz/tap/coremium`, then `open coremium://mode/gaming`,
             and the mode pill switches. Line: "Install it. Automate it." Camera: whip-pan in with motion blur.
          Cut on beats with whip transitions and blur. Never crossfade.
42.0–50.0 Fold.
          - The panel folds into the notch. The ears come alive: a breathing 5-bar meter on the left, "12" on the right.
          - Behind it, an abstract "game" plays: a slow flowing colour field in a canvas, timeline-driven. No real game.
          - At 44.5 a decision toast drops from the notch, "Gaming mode activated · Browser and Chat moved to Yield".
            It holds 1.8 s, then retracts.
          - Line: "Nothing closed." / "What matters stays smooth."
50.0–60.0 End card on the horizon.
          - Logo (128 px) with soft bloom, then "Coremium 2.0".
          - "Keep what matters smooth, without closing anything." in 34 px grey.
          - "Free. Open source. No account."
          - github.com/Cubinghackerz/Coremium in mono, 26 px.
          - 8 frames of silence, then the final hit at 52.0, a long reverb tail, and a fade to black from 58.8.

SOUND (scripts/score.py; Python 3 with numpy only; no samples, no copyrighted music, no AI music)
- 92 BPM, with the grid locked to timeline.json.
- Layers:
  - sub-bass swells
  - filtered-noise risers ending exactly on reveals
  - UI clicks: 3 ms filtered transients, ±8% pitch
  - a warm detuned-saw pad, low-passed, resolving from minor to major at 25.0
  - a soft FM bell on the report card
  - whooshes on whip-pans
  - one wide final hit with a numpy-built exponential-decay reverb
- Sidechain the pad under the clicks. Write film/assets/score.wav (48 kHz, 24-bit) and place it as one <audio> track in
  the master composition.
- Loudness: -14 LUFS integrated, -1 dBTP true peak. Measure with ffmpeg ebur128 and adjust until within 0.5 LU.
- scripts/verify_sync.py fails if any cue is more than one frame from its visual event in timeline.json.

DELIVERABLES (./out)
- coremium-2-launch-1080p60.mp4 (1920×1080, 60 fps, highest quality preset)
- coremium-2-launch-4k.mp4, if the installed version renders 3840×2160 (scale the composition or use the resolution
  flag the skills document; check, don't guess)
- coremium-2-30s.mp4: 00–02, then 17–30, then 50–60, re-timed so the cuts land on beats
- coremium-2-9x16.mp4: 15 s, its own 1080×1920 composition, not a crop. The notch sits in the top third; hook, unfold,
  decision, report card, end card.
- poster.png: the frame at 21.0
- captions.srt: the on-screen lines
- CHECKLIST.md:
  - every on-screen line, mapped to the README sentence or source file that backs it
  - font licences (OFL) and HyperFrames' licence
  - "all audio synthesized in scripts/score.py"
  - confirmation of each hard rule

QA GATES (do all of them; fix and repeat until clean; then stop)
1. Run the HyperFrames lint/validate command the skills document. Fix every warning about timelines, data attributes or
   non-determinism.
2. Render a preview (lower quality is fine). With ffmpeg, extract one frame per beat plus the first and last frame of
   every transition into ./qa. Build a contact sheet and inspect every frame for:
   - clipped, overlapping or widowed text
   - labels that differ from the Swift sources and reference/ui
   - banding
   - off-palette colour
   - any logo, brand or claim the hard rules forbid
   - UI that would not exist in the real app
   - serif fallback fonts
   - flashes of unstyled content on the first frame of any composition
3. Side by side: your panel next to reference/ui/notch-apps.png at the same scale. Spacing, sizes and copy must match.
4. Determinism: render the same 5 s twice and compare frames with ffmpeg (psnr or framemd5). Any difference fails.
5. Motion audit:
   - no UI move faster than 0.4 s
   - no two big moves at once
   - every cut on a beat
   - nothing perfectly still for more than 1.2 s
6. Render the finals. ffprobe each file (duration, resolution, fps, audio stream). Run verify_sync.py and the loudness
   check.
7. Report: files, runtimes, what is recreated, and anything I should approve.
```

## Tips
- Review the preview render first, then give changes per beat ("slow 17–23 by 15%", "softer clicks"). Every time lives
  in `film/timeline.json`.
- HyperFrames runs headless Chrome, so a render loads the CPU for a few minutes. Start it when you're not gaming.
