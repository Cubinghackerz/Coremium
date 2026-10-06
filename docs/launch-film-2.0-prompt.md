# Coremium 2.0 launch film: the cinematic prompt

The aim is the look of Diffusion Studio's site and launch reel: a black void, a horizon of light, real product UI floating
in 3D with depth of field and motion blur, tight grotesk type, and sound that lands on every cut. Everything is built from
code (Remotion + React + a Python-synthesized score), so every frame is exact, editable and honest.

Paste the block below into Claude Code (or Codex), started in any folder.

```
ROLE
You are a motion-design director and a senior TypeScript engineer. Build the launch film for Coremium 2.0 entirely from
code, at the polish of a top product launch reel (Diffusion Studio, Linear, Arc): cinematic 3D camera on real UI,
physically believable light, motion blur, rigorous typography, and a synthesized score cut to picture.

STEP 0 (do this first, yourself)
mkdir -p /Users/nirneet/Movies/coremium-2-film/out && cd /Users/nirneet/Movies/coremium-2-film
Work only in this folder. Read-only source of truth: /Users/nirneet/Documents/GitHub/Coremium
(README.md for every claim; Sources/Coremium/Notch/NotchViews.swift, Tabs/*.swift, Chip/ChipView.swift and
Shared/Theme.swift for exact layout, labels and colours; docs/assets/logo.png; web/src for brand voice).
Also study github.com/Leonxlnx/claude-launchvideo (clone to ./reference, read README, timeline, audio and render
scripts before running anything) for the timeline-driven sync and sub-frame motion-blur technique.

PRODUCT TRUTH (only these claims, worded plainly)
Coremium is a free, open-source Mac app that lives in the notch. While you play, render, code or run a local model, it
moves background apps to the efficiency cores; the app in front stays smooth; nothing is closed. 2.0 adds: a memory and
swap guard; startup helpers you can switch off; session report cards; rules per game; battery-aware moves; automation
(links, Terminal, Shortcuts); in-app updates; a live core meter in the notch and decisions that drop out of it; a Storage
ring with review-before-Trash. Tagline: "Keep what matters smooth, without closing anything."
HARD RULES: no FPS, battery-life, temperature or "X% faster" claims and no invented numbers (numbers shown in the UI are
illustrative and must look like the real UI; tag the recreated UI "Illustrated recreation" in the first and last second).
No Apple logo anywhere (draw a neutral chip mark), no third-party app logos (use neutral rounded squares and generic
names: "Game", "Browser", "Chat", "Music"). End card: "Coremium 2.0", "Free. Open source. No account.",
github.com/Cubinghackerz/Coremium. Never upload, publish or touch the Coremium repo.

LOOK
- World: pure black (#000) with one horizon: a huge soft arc of light below frame (cyan #7DCCF7 core fading to indigo,
  like a planet edge), plus very fine film grain (1–2%, animated, pre-rendered noise texture) and a gentle vignette.
- UI is mostly monochrome (whites/greys) with colour only where it means something: green #73DB9E = protected/active,
  amber #F5BD6B = Boost, sky #7DCCF7 = Yield/performance cores, mint #8CE0BF = Eco/efficiency cores, violet #C4B5FD = GPU.
- Type: "Inter Tight" or "Hanken Grotesk" (Google Fonts, OFL), weights 500/600, tracking -0.04em on headlines, two-tone
  headlines (first clause grey #71717A, second white), never more than 7 words on screen at once.
- Every UI surface is a React recreation rendered at 2x: rounded 30px panels, 1px white/10% hairlines, soft inner
  highlight on top edge, shadow with real offset and blur.

CAMERA AND MOTION
- Treat UI layers as planes in 3D (CSS 3D or @remotion/three): dolly-ins, slow orbits (max 12°), rack focus between
  planes (depth of field via layered blur), parallax between background horizon, panel and foreground text.
- Easing: spring (stiffness 120, damping 20) for UI, expo-out for camera, no linear moves except the grain.
- Motion blur on every fast move: sub-frame accumulation (16 samples on the master, 4 on previews).
- One signature transition used three times: the notch "unfolds" (the black pill grows into the panel with a spring and a
  light sweep across its top edge).
- Light sweeps: a diagonal specular streak crosses glass surfaces on reveals (opacity 0.25, 600 ms).

STRUCTURE (60 s master; every beat in src/timeline.ts)
0:00–0:05  Black. Grain. The horizon slowly rises; a thin bright line forms the notch at top centre. Sub-bass swell.
0:05–0:10  Text, two-tone, letter by letter mask reveal: "Your Mac runs everything" / "on the same fast cores."
0:10–0:17  Eleven core blocks (5 performance, 6 efficiency) float in 3D; app tokens (Game, Browser, Chat, Music) pile onto
           the performance blocks, which flicker amber with strain. Tension pad.
0:17–0:23  The notch unfolds into the Coremium panel (signature transition). Camera dolly-in. Title: "Coremium 2.0".
0:23–0:30  Game becomes active: the decision line types in ("Gaming mode activated. Game became active. Browser and Chat
           moved to Yield, Music to Eco."); tokens glide from performance to efficiency blocks; the performance blocks calm
           to cyan; the notch ears show the live meter. Click sounds on each chip.
0:30–0:42  Feature montage, 2 s each, each a different camera move, each with a 3–5 word line:
           System tab memory guard ("Find what's eating memory."), Startup switches ("Quiet what starts with your Mac."),
           Storage ring with review sheet ("Clear space. Review first."), Rules per game ("Rules for every game."),
           Session report card sliding out of the notch ("See what changed."), Shortcuts/Terminal line `coremium://mode/gaming`
           ("Automate it.").
0:42–0:50  Pull back: the panel collapses into the notch, which keeps glowing with the live meter while a "game" plays
           behind it (abstract moving gradient, not a real game). Line: "Nothing closed. Everything smooth."
0:50–1:00  End card on the horizon: logo, "Coremium 2.0", "Free. Open source. No account.", the GitHub URL, small
           "Illustrated recreation" tag. Final hit, then a long tail.
Also export a 30 s cut (0:05–0:30 + 0:50–1:00) and a 15 s vertical 9:16 cut (unfold, decision, report card, end card)
with the notch re-framed to the top third.

SOUND (synthesize, no samples, no copyrighted music)
Python (numpy, scipy, soundfile, pyloudnorm): 92 BPM grid locked to timeline beats; sub-bass swells, airy filtered-noise
risers before each reveal, crisp UI clicks (short filtered transients), a warm pad that resolves from minor to major when
apps move aside, soft FM bell on the session report, one wide final hit with convolution reverb. Sidechain the pad under
clicks. Loudness -14 LUFS integrated, true peak -1 dBTP. scripts/verify_sync.py fails the build if any cue is more than one
frame off its visual event.

DELIVERABLES (./out)
coremium-2-launch-4k60.mp4 (3840x2160, 60 fps, H.264 high or HEVC, 10-bit if available), coremium-2-launch-1080p60.mp4,
coremium-2-30s.mp4, coremium-2-9x16.mp4, poster.png (frame from 0:20), captions.srt, CHECKLIST.md (every on-screen line
→ the README sentence or source file that backs it; font and audio licences; confirmation of the hard rules).

QUALITY BAR AND VERIFICATION (do all of it, then stop)
1. Preview render at 1080p with 4 blur samples; extract one frame per beat (12 frames) and inspect each for: clipped or
   overlapping text, wrong labels vs the Swift sources, banding in gradients (add dither if seen), off-palette colour,
   any logo or claim the hard rules forbid, UI that would not exist in the real app.
2. Check motion: no move faster than 0.6 s for UI, no two big moves at once, every cut lands on a beat.
3. Fix everything in one pass, render the masters with 16 blur samples, ffprobe each file (duration, resolution, fps,
   audio stream), run verify_sync.py.
4. Ask before installing anything with brew. Report: files, runtimes, what is recreated, anything I should approve.
```

## Tips
- Review the 1080p preview first; ask for changes per beat ("slow 0:17–0:23 by 15%", "softer clicks") since everything
  lives in `src/timeline.ts`.
- For extra authenticity, drop in two or three real screen recordings of the notch (Shift+Command+5) as cut-ins.
