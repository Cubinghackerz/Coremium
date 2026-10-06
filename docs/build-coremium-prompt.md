# Build Coremium: the master prompt (for Claude Code)

This is a complete brief for Claude Code to build Coremium from first principles, at the standard of a shipping,
Apple-Design-Award-calibre Mac utility. It records every product decision and platform fact, plus every bug found in the
current app, so the rebuild doesn't repeat them. Paste the block into Claude Code, started in any folder.

```
ROLE
You are a principal macOS engineer and product designer in one: deep in Darwin scheduling, AppKit/SwiftUI internals,
and the design restraint of Apple's own utilities. Build Coremium end to end. Research, design, implement, test,
render and verify it yourself. Decide; do not ask me design questions. Ask only before anything irreversible or
outward-facing: git push, publishing a release, installing with brew, or touching anything outside the project folder.

STEP 0 — WORKSPACE
mkdir -p /Users/nirneet/Developer/coremium-next && cd /Users/nirneet/Developer/coremium-next && git init
Read-only reference: /Users/nirneet/Documents/GitHub/Coremium, the current shipping app. Read its README.md,
Sources/ and Tests/ first. Use it for behaviour, wording and the lessons below; write better code, not a copy.
Never write to the reference repo. Commit locally in small logical steps with clear messages. Never push.

THE PRODUCT IN ONE SENTENCE
Coremium lives in the Mac's notch. When you play, render, code or run a local model, it protects that app by moving
eligible background apps of the same user to the background priority band (efficiency cores on Apple Silicon). It never
closes anything, explains every decision in plain words, and claims only what it measures.
Tagline: "Keep what matters smooth, without closing anything."

NON-NEGOTIABLES (a violation fails the build review)
1. Only public APIs. No root helper, no private frameworks, no kernel extensions, no SIP workarounds.
2. Touch only the current user's processes. Never quit, kill, suspend or freeze an app automatically. Hide or Quit
   happens only when the user clicks it, and Quit asks first.
3. Every priority change is reversible and journaled before it is made: write ~/Library/Application Support/Coremium/
   demoted.json first, apply second. Restore on Pause, Quit, mode change, crash (on the next launch) and via
   `Coremium --restore-all`.
4. Files go to the Trash only (FileManager.trashItem). Nothing is deleted permanently. The user's own documents are
   never moved, and large files are review-only.
5. Honesty: no FPS, battery-life, temperature or "X% faster" claims anywhere (app, README, site). Show only what is
   measured: protected time, processes moved, Coremium's own CPU cost, and decisions. Label estimates and illustrations.
6. The idle cost budget is the product. Panel closed, no session: ≤ 0.15% of one core and ≤ 40 MB footprint, measured
   by the engine profiler (below). No polling while paused with the panel closed.
7. Privacy: no account, no telemetry. The only network request is a daily GitHub release check the user can turn off.
8. No Apple logo shipped as an asset. If the chip shows Apple's mark, it must be the system SF Symbol drawn at runtime,
   with a "Not affiliated with Apple" line in the README and Settings.

PLATFORM TRUTHS (already verified; build on them, don't re-derive them)
- Lever: setpriority(PRIO_DARWIN_PROCESS, pid, PRIO_DARWIN_BG) and back with 0. This is what `taskpolicy -b` does: lower
  CPU priority, throttled disk and network I/O, efficiency-core preference on Apple Silicon. It works on same-user
  processes without root. There is no public way to raise an app above normal or pin it to performance cores, so
  "Boost" means "protect this app and move others aside". Say so in the UI.
- Process trees: proc_listallpids, proc_pidinfo (PROC_PIDTBSDINFO for ppid/uid), proc_pid_rusage (ri_phys_footprint
  for memory, ri_user_time/ri_system_time deltas for CPU %). Attribute children to the app bundle by walking parents.
  Helpers macOS starts for an app (e.g. Safari's WebContent via launchd) can't be attributed: document that limit.
- Per-core load: host_processor_info deltas. Topology from sysctl hw.perflevel0/1 (P and E counts, L2 sizes),
  hw.memsize, IORegistry gpu-core-count.
- GPU, read-only without root: IOAccelerator › PerformanceStatistics (Device/Renderer/Tiler Utilization %). Each
  AGXDeviceUserClient's IOUserClientCreator ("pid N, name") and AppUsage[].accumulatedGPUTime (ns) give per-app GPU %
  from deltas. The background band does NOT reduce GPU contention: median frame time was 2.1 ms with a normal-priority
  GPU hog and 2.4 ms with the hog in the background band, no hitches in either case. So GPU is measured and explained,
  never "boosted".
- Memory: host_statistics64 (vm_statistics64), vm.swapusage, the kern.memorystatus_vm_pressure_level pressure level.
- Startup helpers: parse ~/Library/LaunchAgents plists. State comes from `launchctl print-disabled gui/<uid>` and
  `launchctl list`. Turn a helper off with bootout plus disable, and on with enable plus bootstrap. Only the user's own
  folder, never /Library.
- Battery: IOPSCopyPowerSourcesInfo. Low Power Mode: ProcessInfo.isLowPowerModeEnabled.
- Notch: NSScreen.safeAreaInsets.top > 0, plus auxiliaryTopLeftArea/auxiliaryTopRightArea for its exact width. Screens
  without a notch get a compact pill at the top centre.
- Fullscreen stutter (macOS 27, 120 Hz ProMotion): fullscreen Metal apps use Direct-to-Display, which breaks frame pacing.
  Any other on-screen window forces normal compositing. The fix is a 2 pt, click-through, never-key window at
  .screenSaver level with [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]. It must exist ONLY on
  a display that is showing a fullscreen app. A permanent overlay made window dragging feel wrong.
  Detection is measured on macOS 27 with CGWindowListCopyWindowInfo. It needs only owner pid, layer, bounds and alpha,
  so no Screen Recording permission:
  - With the menu bar shown in fullscreen, the menu bar window stays listed.
  - A fullscreen window then has EXACTLY the frame of a maximized one: below the menu bar, down to the bottom edge.
  - The difference is AppKit's fullscreen title-bar window: same pid, same top-left corner and width, shorter, and
    listed with alpha 0 until hovered.
  - Borderless fullscreen games cover the whole display from its top edge.
  So a display counts as fullscreen when either holds:
  (a) a layer-0 window of another app covers the full width and reaches the bottom from the top edge, or
  (b) it starts within 50 pt of the top AND that app has the title-bar window. Match the title bar regardless of alpha.
  Re-evaluate on activeSpaceDidChange, didActivateApplication, didTerminateApplication and screen changes, at 0, 0.8 and
  2 s after each event. Poll every 3 s only while a fix window exists.
- In-app updates: GET api.github.com/repos/<owner>/<repo>/releases/latest and compare versions numerically, not as
  strings. Download the zip, verify SHA-256 (CryptoKit) against the release's .sha256 asset, and unpack with
  `ditto -x -k`. Then run a detached /bin/sh script that:
  1. waits for our pid to exit
  2. moves the old app aside
  3. ditto-copies the new one
  4. on failure, removes the partial copy and restores the old app
  5. reopens the app
  Never delete the old app before the new one is in place.
- Automation:
  - a `coremium://` URL scheme: mode/<name>, pause, resume, open[/tab]
  - CLI flags forwarded to the running instance as URLs: --mode, --open, --pause, --resume, --restore-all
  - AppIntents (macOS 13+) plus an AppShortcutsProvider: Set mode, Pause, Resume

PRODUCT SPEC
Modes, with one row of named pills: Automatic (default), Balanced, Gaming, Creator, Coding, Local AI.
- Automatic follows the app in front, or a busy game/creator/AI app. Its pill reads "Automatic · Gaming" with what it
  chose. If names don't fit, unselected pills fall back to icons through ViewThatFits; never truncate.
- Mode table:

  | Mode     | Protected (boost)                   | Moved aside during a session                    |
  |----------|-------------------------------------|-------------------------------------------------|
  | Gaming   | games                               | creative, dev, browsers, chat, AI assistants    |
  | Creator  | video, audio, 3D, design            | games, browsers, chat, AI                       |
  | Coding   | editors, terminals, builds          | games, creative                                 |
  | Local AI | LLM tools, image generation, VMs    | games, creative, browsers, chat                 |
  | Balanced | nothing automatic; only per-app choices                                                |

- Adaptive Automatic, all local:
  - It moves busy eligible background apps only when average P-core load is ≥ 80% for 6 s (all cores on Intel) and each
    app uses ≥ 25% of a core for 6 s.
  - It recovers at ≤ 55% for 12 s, with a minimum 15 s hold and a 10 s cooldown.
  - Missing samples or a long sampling gap release its choices safely.
  - Busy builds, renders and local models are never moved. A setting turns this off.

Per-app choices: Boost, Normal, Yield, Eco. An explicit choice always beats the mode and the default protected list.
That list (Finder, Dock, Music, Spotify, Coremium) protects only by default; only a small systemEssential set can never
be demoted. (Bug fixed in the shipping app: Spotify set to Eco was ignored because the protected list beat the user.)
- Rules per game: while a game is boosted, a scope switch "Everyone / <Game> only" edits gameRules[game][app]. Chips
  always show the choice for the scope being edited. (Fixed bug: chips showed merged rules regardless of scope.)
- Sessions: a boost app in front starts one. It ends 90 s (configurable) after the boost app stops being used. An
  option keeps protecting a busy boosted app running in the background.
- Battery-aware (default on): unplugged, apps working hard in the background move to the efficiency cores without a
  boost, unless the user set them to Normal.
- App recognition:
  - a built-in table of bundle IDs
  - LSApplicationCategoryType
  - the Steam library location
  - local-AI tool names
  Index /Applications, ~/Applications and Steam with FSEvents. Cache the index and never wait on Spotlight.
- Learning, local: suggest Yield for apps that hog the CPU during boosts and Boost for apps worked in hard. Never apply
  a suggestion without approval.

NOTCH UI (SwiftUI in a borderless, non-activating NSPanel)
- Collapsed:
  - The notch looks untouched, with optional "ears" beside it: a mode icon and status dot. "Show indicators" off makes
    them hidden in plain sight.
  - During a session the ears become a live P-core meter on the left and an apps-moved count on the right.
  - Hover or a menu-bar click expands the panel. While a fullscreen game is in front, the pill ignores the mouse.
- Expanded panel, 780×488 pt:
  - Left column: the chip die with P and E tile rows. Tiles show white intensity, turning amber above 85% only. Below
    them: specs (cores, GPU, memory, L2, power, thermal).
  - Right column:
    - ModeBar
    - a right-aligned row with the Advanced toggle and Hide (a separate row, because the mode names fill the ModeBar row)
    - a StatusLine in plain words, e.g. "Protecting Roblox · 23 background processes at lower priority"
    - an UpdateBanner
    - the TabBar, then tab content
- Tabs: seven named tabs (Apps, Insights, Storage, System, Simulate, Guide, Settings), no icon-only tabs.
  - Hit targets at least 30 pt tall.
  - ⌘1–⌘7 and Control-Tab / Control-Shift-Tab (wrapping), handled in the panel controller, never as app-wide shortcuts.
    ⌘0 and ⌘8 do nothing.
  - Left/Right arrows move between tabs only while a tab has focus, so sliders keep their arrow keys.
  - Draw your own focus ring: black on the selected (white) tab, white on the others. Turn off the system ring with
    focusEffectDisabled on macOS 14+.
  - Focus entering the bar lands on the selected tab and follows clicks and shortcuts. (Fixed bug: focus defaulted to
    "Apps", so two tabs looked selected.)
- Apps: Running and Installed lists. Each row shows:
  - icon, name and a kind line ("Steps aside during boosts", "Always on efficiency cores", "Protected")
  - an outcome word instead of raw numbers: Light / Moderate / Heavy / Background / GPU heavy
  - Boost / Normal / Yield / Eco chips
  Advanced adds a second line with CPU %, pid, process count and the reason. Long names truncate with an ellipsis and
  never push the chips. At the bottom, a proof strip shows measured facts plus "Coremium overhead X% of one core", with
  Details. Pause reads "macOS default scheduling restored".
- Insights:
  - a 14-day strip of cells, not bar charts
  - a decision log, e.g. "Gaming mode activated. Roblox became active. Chrome and Discord moved to Yield, Spotify to Eco."
  - session report cards (only for boosts of 60 s or more), with Copy image via ImageRenderer
  - the energy figure, labelled as an estimate
- Storage, the DiskBuddy-class ring:
  - Show a donut of disk use with category segments: app caches, logs, developer build files, old downloads, Trash, and
    large files (review-only).
  - Scan categories in parallel and progressively. Each category has its own run token, so a "Find large files" scan
    can't discard a running standard scan. (Fixed bug: Storage stuck on "Scanning…".)
  - A 15 s watchdog explains hidden TCC permission prompts.
  - The model is a persistent singleton, so closing the panel doesn't restart the scan.
  - Only direct children of allowed roots can be selected. Skip symlinks and keep a keep-list.
  - Skip caches of running apps, matching by bundle id and by app name, because Chrome's cache folder is "Google".
  - Review sheet: totals, warnings ("Includes N of your downloads"), Move to Trash, confirm. Show the result as
    "Moved X to the Trash. Nothing is deleted until you empty it."
- System:
  - a memory card with pressure, swap and the top memory users, each with Hide and "Quit…" (Quit confirms first)
  - a swap-growth warning during boosts
  - startup helpers with reversible switches, plus a link to Login Items
- Simulate: an animated illustration of P and E cores, clearly labelled as an illustration.
- Guide: the honest explanation, plus "If something looks wrong" with the --restore-all command.
- Settings: all toggles with one-line explanations, a Return-to-normal slider, Rescan, Restore all apps now, Welcome
  tour, and Reset settings… (with confirmation). The footer reads "Coremium <version> · MIT license · not affiliated with
  Apple".
- Notch toasts (Dynamic-Island style): decisions, the end-of-session report and "Coremium X is available" drop out of
  the notch for 3.4 s. The panel frame grows by 300×34 and is click-through. A setting turns them off.
- First launch: a short screen showing real activity right away; the full tour is optional.
- Menu-bar extra: Show/Hide Coremium, modes, Pause, Fullscreen fix, Show indicators, "Update to Coremium X…", Quit.
  Quitting restores everything.

DESIGN SYSTEM
- Mostly monochrome, dark: background #0A0B14, cards white 5.5%, hairlines white 9%, dim text white 55%. White is the
  accent.
- Colour only where it carries meaning:
  - good #73DB9E: active / protected
  - boost #F5BD6B: Boost, hot cores
  - yield #7DCCF7: Yield, performance cores
  - eco #8CE0BF: Eco, efficiency cores
  - gpu #C4B5FD: GPU
  - warn #EDC785: warnings
- Type: SF Pro Rounded (system, .rounded), 10.5–13 pt in the panel, monospaced digits for numbers, SF Mono for Advanced.
- Motion: 0.25 s easeInOut for expand and collapse; springs only for small toasts. No bar charts. Copy is plain,
  outcome-first and never jargon by default; Advanced holds the numbers.
- The app icon is a cyan-to-indigo chip. Render it from code (a make-icon script) at every size.

ARCHITECTURE
- XcodeGen (project.yml) produces three targets:
  - CoremiumCore: a pure framework holding every decision and parser, with no AppKit
  - Coremium: the app (AppKit + SwiftUI)
  - CoremiumCoreTests
  Deployment target macOS 13.0, universal (arm64 + x86_64), Swift 5.10+, strict concurrency where practical. LSUIElement
  app with the CFBundleURLTypes coremium scheme.
- Core files, one concern each: ChipInfo, CPULoad, CPUUsage (ProcessCPUSampler), ProcessSnapshot, AppCategory, Rules
  (RuleSet, gameRules, merged(forBoost:), RuleEvaluator, systemEssential), PriorityController (with an injectable
  backend and DemotionLedger), AdaptiveAutomatic, EngineSamplingPlan (cadences), UsageStats (DayStats, SessionReport,
  UsageLedger: tolerant decoding, 30 reports kept), GPUStats, MemoryInfo, LaunchAgents, Storage, Updates,
  FullscreenDetection, SimulationModel, WorkloadLearner.
- App layer: AppEngine (MainActor; one coalesced timer plus app events; evaluate → diff → apply through the controller →
  publish), NotchController (window, frames, hover, toasts, keyboard routing, runRegressionChecks), NotchViews and Tabs/*,
  Chip/ChipView, Onboarding, FullscreenFix, Updater, Automation, LoginItem (SMAppService), Theme, Logo.
- Sampling budget:
  - Normal ticks: 10 s idle, 4 s in a session, 2 s with the panel open. Low Power Mode: 20, 6 and 3 s.
  - GPU and memory: sample only when the panel is visible or a session is running. At most every 12 s during a closed
    session, every 4 s when visible, and per-process footprints at most every 6 s while visible.
  - App index refreshes on FSEvents only. Timers carry tolerance.
- Settings: Codable JSON with tolerant decoding (decodeIfPresent and defaults for every key), so old files never fail.
  COREMIUM_DATA_DIR overrides the folder for tests and previews.
- PREVIEW build flag: a backend that cannot change priorities, AppEngine(isPreview:) and injectPreview(...) for sample
  data.

TOOLING YOU MUST BUILD (this is how quality gets proven, not claimed)
1. Unit tests for every core decision:
   - rule precedence (explicit choice vs mode vs protected vs systemEssential)
   - per-game merge and scope
   - the adaptive thresholds, hold and cooldown
   - ledger restore after a simulated crash
   - storage eligibility (symlinks, roots, keep-list, empty lists, in-use caches by name)
   - storage scan run tokens
   - semver and release parsing
   - GPU delta math and parsing "pid 671, com.apple.dock.e"
   - LaunchAgent parsing
   - tolerant settings decoding
   - fullscreen detection, using the real frames above: maximized → none; title bar (alpha 0) → yes; borderless → yes;
     another app's title bar → no
   - sampling-plan cadences
2. scripts/render-previews.swift and .sh: compile the app sources with -D PREVIEW and render every tab (normal and
   Advanced), the collapsed pill, onboarding and first use to PNG at 2x with ImageRenderer. Known ImageRenderer limits:
   - It can't draw ScrollView, Toggle or Slider: Toggle shows a yellow placeholder, and scroll areas need a "renderFlat"
     environment switch that lays them out flat.
   - It renders the Apps tab dimmed.
   So also build a LIVE check: host NotchRootView in an offscreen NSHostingView window, scroll every NSScrollView to its
   end, snapshot with cacheDisplay, and report each scroll view's frame against the panel. That catches clipped bottoms
   and wrong focus rings that ImageRenderer can't show.
3. NotchController.runRegressionChecks (run with --test-notch), printing PASS/FAIL lines and exiting non-zero on any
   failure:
   - hover and collapse races
   - Escape dismisses a pinned panel
   - onboarding completion
   - ⌘1–⌘7, Control-Tab wrap, ⌘0 and ⌘8 rejected
   - shortcuts shielded while the panel is inactive or the tour is showing
4. An engine profiler (--profile-engine with throwaway settings) that prints % of one core and MiB for idle, closed,
   paused and open. It must meet the budget.
5. scripts/build.sh produces Release, universal, ad-hoc signed Coremium.app, plus a zip, a DMG (hdiutil, with an
   "If macOS blocks it.txt" note) and Coremium-<v>.sha256 with LF line endings. scripts/install.sh downloads, checks the
   checksum and installs.
6. CI (.github/workflows): ci.yml runs build and tests on macos-latest; release.yml runs on v* tags and uploads the zip,
   dmg and sha256. Write them; don't trigger them.

LESSONS FROM THE SHIPPING APP (each was a real bug; design so it can't happen)
- An empty list passed to DispatchQueue.concurrentPerform: guard it.
- One slow folder or a hidden TCC prompt blocked the whole storage scan: scan per kind, with a watchdog.
- zsh `rm -f *.zip` with no match aborts a chain: use `setopt null_glob` or `find`.
- The mode bar plus actions on one row dropped the mode names: keep the separate actions row.
- Text set inside panels rendered black in previews: set foregroundColor explicitly; never rely on inherited colour.
- Windows sibling (out of scope here, kept for reference): PowerShell Invoke-RestMethod arrays need parentheses before
  piping, and CRLF broke the checksum.

MILESTONES (each ends green: build, tests, previews, live check, regression, profiler)
M1 Core: topology, CPU, processes, rules, priority controller with ledger, and tests.
M2 Engine: the AppEngine loop, sessions, Automatic plus adaptive, battery, learning, and the profiler meeting budget.
M3 Notch shell: geometry, panel, collapse/expand, ears, toasts, keyboard routing, and regression checks.
M4 Apps, Insights, Settings, Guide, Simulate, and onboarding.
M5 Storage and System.
M6 Fullscreen fix (with detection tests), Updater (safe swap, tested for success and forced failure), Automation
   (URL scheme, CLI and Intents tested live).
M7 Packaging, README (honest "How it works, and what it can't do", Known limitations, Tested on, Uninstall), SECURITY.md,
   CONTRIBUTING.md, CI.

FINAL VERIFICATION (do all of it, then report)
- xcodebuild test: all green. Release build: universal binary (check with lipo -info).
- Previews plus the live check: no clipped text, no truncated tab title or mode name, every scroll bottom reachable,
  focus ring only on the selected tab.
- Run --test-notch and the profiler, and report the numbers against the budget.
- Live, on this Mac:
  1. `open coremium://mode/coding` switches the mode, and `--mode automatic` switches it back.
  2. The demotion ledger survives `kill -9`, and the next launch restores it.
  3. --restore-all works.
  4. With the Fullscreen fix on, dragging and tiling ordinary windows behaves like stock macOS (no fix window listed).
     A fullscreen app gets the window within 2 s and loses it on exit.
- The report covers: what was built, test, profiler and regression results, screenshots of every tab, known limits,
  and anything that needs my approval (signing, release, push).
```

## Notes
- The prompt deliberately points at the current repo as a read-only reference. Claude gets the real wording and
  behaviour without inheriting old structure.
- To rebuild in place instead of in `~/Developer/coremium-next`, change Step 0. Keep "never push" unless you want it to
  publish.
