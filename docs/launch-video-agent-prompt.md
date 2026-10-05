# One-shot prompt: an AI agent makes the Coremium launch video

Paste everything inside the code block into Claude Code or Codex, started in `~/Documents/GitHub/Coremium` with the
Diffusion Studio desktop app open (it registers its MCP tools automatically; check with `claude mcp list`).
Before you start: close personal windows, turn Do Not Disturb on, and grant your terminal Screen Recording (and, for the
automatic mouse moves, Accessibility) in System Settings > Privacy & Security.

```
GOAL
Make the launch video for Coremium (a free, open-source macOS notch app that moves background apps to the efficiency
cores while the game or work app in front stays smooth; nothing is quit). Deliverables in ~/Movies/coremium-video/out:
  coremium-launch-16x9-1080p.mp4 (about 45 s), coremium-launch-16x9-4k.mp4, coremium-launch-9x16.mp4 (15 s),
  poster.png (thumbnail), captions.srt, CHECKLIST.md (every claim in the video mapped to an app feature).
Work autonomously. Ask me only if a macOS permission prompt needs my click, or a step below says to stop.

READ FIRST
- docs/launch-video.md (storyboard + content rules), README.md, docs/assets/logo.png.
- Content rules are strict: no FPS, battery, temperature or "X% faster" claims; the Simulate tab, if shown, is captioned
  "Illustration"; say free, open source (MIT), no account, no network access, ad-hoc signed/not notarized; the end card says
  "Not affiliated with Apple". Do not show personal data (account names, notifications, file paths, other windows).

TOOLS
- Diffusion Studio via its MCP tools (media_probe, media_filmstrip, media_waveform, media_transcribe, media_grab, plus
  the editor/composition tools). Project folder: ~/Movies/coremium-video/project (JSX compositions). If skills are missing:
  `npx skills add diffusionstudio/skills`.
- macOS: `screencapture -v -V <seconds> file.mov` to record, `ffmpeg` for trims/conversion (install with brew only if
  missing and tell me first), Swift scripts for mouse moves (CGEvent).

STEP 1: CAPTURE REAL FOOTAGE (preferred)
1. Verify /Applications/Coremium.app is running (`pgrep -x Coremium`); if not, `open -a /Applications/Coremium.app`.
2. Write scripts/video/mouse.swift that moves the cursor smoothly (eased, 0.6 s) to the notch (top centre of the main
   display), pauses for the hover dwell (0.5 s), moves to a given point, and clicks. Test it once. If it needs
   Accessibility permission, stop and tell me exactly what to enable, then continue.
3. Record these takes at native resolution into ~/Movies/coremium-video/raw (hold still 1 s at start and end of each):
   01-hover-expand (hover notch, panel opens), 02-apps-chips (click Yield on one app, then click it again to undo),
   03-modes (click each mode pill: Automatic, Balanced, Gaming, Creator, Coding, Local AI), 04-advanced (click
   Advanced on, scroll the list slowly, off), 05-insights (open Insights tab), 06-pause (click Pause, read status, Resume),
   07-menu (click the menu-bar chip icon, show the menu with Hide Coremium). For the decision-line shot, record
   08-decision: bring Terminal to the front, then a Boost app (the game or any app set to Boost), so the line under the
   status explains the change. Use only Coremium's UI and apps I already have open; do not open or change anything else.
4. Probe each take (media_probe, media_filmstrip). Reject takes with notifications or personal info; re-record them.

STEP 2: FALLBACK IF CAPTURE IS IMPOSSIBLE (no permission, or takes are unusable)
Build the same scenes as motion graphics: run `scripts/render-previews.sh ~/Movies/coremium-video/preview` (offscreen
PNGs of Apps, Apps-Advanced, Insights, Guide, onboarding; never launches the app) and animate them with zoom, pans and
typed captions. Avoid screens that show yellow "no entry" placeholders (native toggles/sliders: Settings, Simulate),
or crop them out. Mark any non-live visuals "Illustration" in a corner tag.

STEP 3: EDIT IN DIFFUSION STUDIO
1. Composition: 3840x2160, 30 fps, about 45 s, following the storyboard table in docs/launch-video.md. Best 3 to 5 s of
   each take, 0.2 s cross-dissolves, eased punch-in zooms (1.0 to 1.25) on the notch region, captions as dark translucent
   lower-thirds with 6% safe margins, rounded sans font (Inter unless a licensed alternative exists).
2. Voice-over: write the script from the storyboard "On-screen text" column (about 85 words). Generate speech with
   Diffusion Studio's audio generation if available; otherwise macOS `say -v "Samantha" -o vo.aiff` (tell me the voice is
   a placeholder). Add a royalty-free/CC0 or generated music bed ducked 12 dB under the voice; record the licence in
   CHECKLIST.md. Loudness -14 LUFS, true peak -1 dBTP; verify with media_waveform.
3. Captions: media_transcribe the voice-over, burn in subtitles (max 2 lines, 42 chars), export captions.srt.
4. End card: logo, "Coremium", "Free. Open source. No account.", the text "github.com/Cubinghackerz/Coremium"
   (only if the repo exists: check with `gh repo view Cubinghackerz/Coremium`; otherwise use "Coming soon"), and
   "Not affiliated with Apple."
5. Vertical cut: 1080x1920, 15 s from hover-expand, decision line and end card, notch kept in the top third.
6. Render, then verify each file with `ffprobe` (duration, resolution, audio present) and inspect 6 evenly spaced
   frames per video with media_filmstrip for clipped text, personal data, wrong captions or placeholder artefacts.
   Fix and re-render until clean.

STEP 4: HONESTY AUDIT
Write CHECKLIST.md: each on-screen claim -> the README line or app feature that backs it; list music/font/voice licences;
confirm no performance, battery or temperature claim and no personal data appears. If any item fails, fix the video.

STOP RULES
- Do NOT upload, post, email, or attach the video anywhere, and do not git commit/push anything. Only create files under
  ~/Movies/coremium-video and scripts/video in the Coremium repo.
- Do not change Coremium's settings permanently: undo any rule/mode changes you made while recording (set Mode back to
  Automatic, clear per-app overrides you added, Pause off).
- Finish with a short report: files produced, their paths, runtime, what was real footage vs illustration, and anything
  I should re-record or approve.
```
