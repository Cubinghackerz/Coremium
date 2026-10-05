# Coremium: handoff prompt for the next coding agent

Paste everything below the line into a coding agent opened in the Coremium repo.

---

You are continuing work on **Coremium**, a notch-based macOS app (Swift 5 mode, SwiftUI + AppKit, XcodeGen) that moves
background apps to the efficiency cores while the user's game, render, build or local-AI job is in front. Nothing is
quit. Read `README.md`, `SECURITY.md` and `CONTRIBUTING.md` first. All logic is in `Sources/CoremiumCore` (unit tested);
`Sources/Coremium` is the notch UI. Build: `scripts/build.sh`. Tests: `xcodebuild -project Coremium.xcodeproj -scheme CoremiumCore test` (61 pass).

## Non-negotiables
- Honesty is the product. Never claim battery life, temperature or "X% faster" that is not measured. Evidence comes from
  the stability test and the usage ledger. The stability test was removed on purpose.
- Only touch the current user's processes, keep every change reversible (`DemotionLedger`, `--restore-all`).
- Do not commit personal paths or data. Do not `git push`, create the GitHub repo, tag a release or announce anything
  without the user's explicit yes in chat.
- Edit existing files; keep comments about why, not what.

## State (2026-10-05)
Built and installed at `/Applications/Coremium.app`; 61 tests green; universal ad-hoc zip in `dist/`; no git commit yet.
Recently changed (verify these live, offscreen previews cannot show them):
1. **Decision log**: `AppEngine.decisions` / `logDecision` explain every change ("Coding mode activated. Terminal became
   active. Chrome moved to Yield and Spotify to Eco."). Shown under the status line and in Insights ("Why Coremium did
   what it did").
2. **Proof strip** at the bottom of Apps (today's protected time, what is moved right now, Coremium's own CPU cost).
3. **Labels** on every mode, Yield explained per row ("Steps aside during boosts"), outcome words (Light / Moderate /
   Heavy / Background) next to the CPU figure, "Found N apps" only on the Installed list, Pause moved to the list header
   with "macOS default scheduling restored" shown immediately, fullscreen fix only in Settings and onboarding.
4. **Hide Coremium**: chevron button in the tab bar and a Hide/Show item in the menu-bar menu.
5. **Advanced rows** no longer truncate (category/rule on line 1, `pid · procs · eco · source` on line 2); chip die
   scales its logo and pins when small.
6. **Stability test removed entirely** (code, UI, CLI flag, tests, docs) by the user's decision.
7. **Spotify bug fixed**: an explicit Yield/Eco choice now beats the default protected list; `RuleSet.systemEssential`
   (Coremium, Finder, Dock, system UI) is never moved. Covered by a unit test.

## Top product priority: show what Coremium changed (the "evidence" gap)
An outside review of the Advanced screen (P 11% avg, E 32% avg, thermal nominal, Chrome on Yield, Spotify on Eco, memory
72%, pressure "warning") scored the telemetry and UI about 9/10 but the evidence of benefit about 4/10, because the
screen said **"Moved: 0 procs"** and **"0 procs on E-cores"**. Its core point: E-core load is mostly macOS's own work, so
busy E-cores prove nothing about Coremium. The app must keep answering: *"What did Coremium just improve that macOS would
not have done by itself?"* The reviewer wanted things like "18 processes moved to E-cores", "P-core background load
21% to 11%", power in watts, "Chrome background activity reduced 31%", "Coremium overhead 0.3% CPU", and a small
COREMIUM IMPACT box (P-core load down, power down, processes optimised, temperature down).

What is and is not possible without root or a paid account (do not overclaim):
- **Measurable, show it:** processes/apps currently moved; core-seconds of work moved to the efficiency band (already in
  `UsageLedger.movedCoreSeconds`); per-app CPU before vs while moved; P-core load average with Coremium active vs the same
  app mix paused (a short, labelled A/B with the Pause toggle); Coremium's own overhead
  (its CPU % and memory, from `proc_pid_rusage` on itself); time protected.
- **Not measurable, never claim:** package power in watts (needs `powermetrics`/root), temperature in degrees, battery
  life. Keep the labelled Wh estimate only as an estimate, or drop it if it reads as a claim.
- **"tick 19.4 ms"** is how long one evaluation pass takes, not how often it runs (it runs every 1 s with the panel open,
  3 s during a session, 5 s idle). Show "overhead 0.3% CPU" next to it, and keep the engine light.

Concrete tasks:
1. Make the empty state useful: when "Moved" is 0, say why in plain words ("Nothing is being moved because no Boost app
   is in use. Yield apps step aside once one is.") instead of a bare 0. Tie it to the decision log.
2. Add a **Coremium impact** card (Apps tab proof strip and Insights): processes moved now, moved core-minutes today,
   P-core average with vs without (only from real samples; show "not enough data yet" otherwise), overhead %, and the last
   overhead. Every figure measured or clearly labelled.
3. Per-app "before vs now" in Advanced: CPU use before it was moved vs now, from samples already taken each tick.

## Do next, in order
0. Do the product-priority tasks above first if the user asks for them; otherwise continue below.
1. Launch the installed app and review every tab with Advanced on and off (Apps, Insights, Simulate, Guide, Settings,
   Welcome tour via Settings). Check: no truncated text, the decision line appears when you switch from Terminal to a
   Boost app, Pause shows "macOS default scheduling restored", the chevron and menu "Hide Coremium" collapse the panel.
2. Check the proof strip and Insights show sensible live numbers during a real session.
3. 30-minute real Roblox (or other game) session on the **dist** build in Automatic mode; afterwards
   `ls ~/Library/Logs/DiagnosticReports | grep -i coremium` must be empty. Confirm the fullscreen fix window exists
   (2x2, layer 1000) while a game is fullscreen.
4. External display / non-notch Mac: the menu-bar icon must always open the panel.
5. Fresh-install check: `COREMIUM_DATA_DIR=$(mktemp -d)` plus `defaults delete com.cubinghackerz.coremium`, launch,
   walk the tour, toggle Open at login.
6. Take real screenshots (not `scripts/render-previews.sh` output, which has preview-only placeholders) for the README.
7. Update `README.md` "Tested on" with anything newly verified.
8. When all above pass, ask the user for permission, then: first git commit, `gh repo create Cubinghackerz/Coremium
   --public --source=. --push`, wait for CI green, tag `v0.1.0`, verify the release zip checksum.

## Known limits (do not "fix" by overclaiming)
Boost is indirect; helper XPC services are not attributed; ad-hoc signed (not notarized); only macOS 27 / M3 Pro tested.
