# Coremium launch video: plan and agent prompts

Goal: a 40 to 50 second video (16:9, 4K or 1080p) plus a 15 second vertical cut, made in **Diffusion Studio** (open-source,
agent-driven editor) with Claude Code or Codex. Message: **"Keep what matters smooth, without closing anything."**

## Rules for the content (honesty is the product)
- Show only what Coremium really does: moves background apps to the efficiency cores while your game or work app is in front;
  nothing is quit; you choose per app (Boost / Normal / Yield / Eco); it explains each decision.
- **Do not** claim FPS gains, battery life, temperature or "X% faster". No before/after performance numbers. The Simulate tab
  is an illustration; if it appears, caption it "Illustration".
- Say plainly it is free, open source (MIT), no account, no network access, and **not notarized** (macOS asks once).
- The chip graphic uses Apple's own logo symbol. Add "Not affiliated with Apple" in the end card. No Apple branding elsewhere.
- Music and fonts must be licensed for commercial use (use the editor's generated audio or a CC0 track; keep the licence note).
- Do not publish the video or post links anywhere without the user's explicit yes. The GitHub repo must exist first.

## Storyboard (about 45 s)
| Time | Visual | On-screen text / voice-over |
|---|---|---|
| 0:00 to 0:04 | Real recording: game running, Chrome and chat open, cursor hovers the notch | "Your Mac runs everything on the fast cores." |
| 0:04 to 0:09 | Notch expands (spring animation). Camera punch-in on the chip and live core bars | "Coremium lives in the notch." |
| 0:09 to 0:16 | Apps tab: Boost / Normal / Yield / Eco chips; click Yield on Chrome; "Background" tag appears | "Pick which apps get out of the way. Nothing is closed." |
| 0:16 to 0:23 | Decision line: "Coding mode activated. Terminal became active. Chrome moved to Yield." Highlight the line | "Automatic mode tells you why." |
| 0:23 to 0:29 | Switch modes: Gaming, Creator, Coding, Local AI (labels visible) | "Gaming. Creator. Coding. Local AI." |
| 0:29 to 0:35 | Advanced toggle: per-core %, memory, PIDs, rule source | "Want the numbers? Advanced shows everything." |
| 0:35 to 0:40 | Pause button: status "macOS default scheduling restored." | "One click puts everything back." |
| 0:40 to 0:45 | End card: logo, "Coremium", "Free. Open source. No account.", GitHub URL, "Not affiliated with Apple." | CTA |

Vertical cut (15 s): 0:04 to 0:09 expand, 0:16 to 0:23 decision line, 0:40 to 0:45 end card.

## Assets to capture (do this first, by hand)
1. Prepare the Mac: clean wallpaper, Do Not Disturb on, hide unrelated menu-bar items, system cursor size larger
   (System Settings, Accessibility, Display, Pointer), Coremium **Show indicators in the notch** on, Advanced off.
2. Record with the macOS screen recorder (`Shift+Command+5`, "Record Entire Screen", Options: show mouse clicks, save to
   `~/Movies/coremium-video/raw`). Native resolution, one take per storyboard row, 10 s each, hold still 1 s at the start
   and end of every take.
3. Takes needed: `01-hover-expand`, `02-apps-chips`, `03-decision-line` (switch from Terminal to a Boost app such as the
   game; the line appears under the status), `04-modes`, `05-advanced`, `06-pause`.
4. Optional b-roll: the game running (Roblox) for 5 s; macOS menu-bar icon opening the menu (Show/Hide Coremium).
5. Logo: `docs/assets/logo.png`. Voice-over: record a clean WAV (Voice Memos or QuickTime audio) or use generated speech.

## Tooling setup
1. Install **Diffusion Studio** (desktop app, or `git clone https://github.com/diffusionstudio/editor`, `npm install`,
   `cp apps/web/.env.example apps/web/.env`, `npm run dev`). The desktop app registers its MCP server with supported agents
   automatically; confirm in the agent with `claude mcp list` (Claude Code) or the Codex MCP list.
2. Add the editing skills: `npx skills add diffusionstudio/skills`.
3. Create a project folder `~/Movies/coremium-video/project`. Projects are folders of JSX compositions; edits on the canvas
   write code and code changes redraw the canvas, so the agent and you stay in sync.
4. Import the raw takes and `logo.png` into the project. Agents can inspect footage with `media_probe`, `media_filmstrip`,
   `media_waveform` and `media_transcribe`.

## Prompt 1: rough cut (paste into Claude Code or Codex in the project folder)
```
You are editing the launch video for Coremium, a free open-source macOS notch app that moves background apps to the
efficiency cores while your game or work app is in front. Read docs/launch-video.md in the Coremium repo
(~/Documents/GitHub/Coremium) for the storyboard and the content rules; follow them exactly.

Use the Diffusion Studio MCP tools. Steps:
1. Probe every file in ./raw with media_probe and media_filmstrip. Write a short shot list (file, usable in/out times,
   what is on screen) to ./notes/shots.md.
2. Build a 16:9, 3840x2160 (or 1920x1080), 30 fps composition of about 45 s following the storyboard table. Use the
   best 3 to 5 seconds of each take, trim the still frames at start and end, add 0.2 s cross-dissolves, and punch-in
   zooms (1.0 to 1.25) on the notch area in rows 2, 4 and 5.
3. Add lower-third captions for every row using the "On-screen text" column. Font: a clean rounded sans (system
   SF-style if licensed, otherwise Inter). Dark translucent pill behind text, 90% opacity, safe margins 6%.
4. Add the end card (logo.png, "Coremium", "Free. Open source. No account.", the GitHub URL I give you, and the line
   "Not affiliated with Apple.").
5. Do NOT add any performance numbers, FPS claims, battery or temperature claims.
6. Render a 1080p preview to ./out/rough.mp4 and report the timeline, any gaps in the footage, and what to re-record.
```

## Prompt 2: polish pass
```
Open the existing Coremium composition. Do these in order and render ./out/v2.mp4 after each:
1. Audio: add the voice-over from ./audio/vo.wav, duck any music 12 dB under it, add a soft whoosh at each cut, loudness
   target -14 LUFS integrated, true peak -1 dBTP. Check with media_waveform.
2. Captions: transcribe the voice-over (media_transcribe) and add burned-in subtitles, max 2 lines, 42 characters per line.
3. Motion: ease all zooms (cubic out), keep cuts on beats of the music, nothing moves faster than 0.5 s.
4. Brand: logo gradient (cyan to violet) only on the end card and a small watermark at the top right at 40% opacity.
5. Make a 9:16 cut (1080x1920, 15 s) from rows 2, 4 and 8; re-frame the notch region to the top third and keep
   captions in the middle third.
6. Write ./out/CHECKLIST.md listing every claim made in the video and the app feature that backs it.
```

## Review checklist before publishing
- Every statement matches the README and the app; no performance, battery or temperature claim; "Illustration" caption if
  the Simulate tab appears; "Not affiliated with Apple" on the end card.
- The footage shows the installed release build, version number matches the release, no personal data on screen (account
  names, notifications, file paths, other windows).
- Licences recorded for music, fonts and any generated media; export H.264 or HEVC, 1080p and 4K, plus 9:16.
- Ask the user for explicit approval before uploading anywhere (YouTube, X, Reddit, Hacker News) or attaching it to the
  GitHub release.
