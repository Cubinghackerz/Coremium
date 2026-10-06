# Coremium

<img src="docs/assets/logo.png" width="96" align="right" alt="Coremium logo">

**Give the app you're using more room to work.**

Coremium lives in your Mac's notch. It protects the app you're using (a game, a render, a build, a local AI job) by
lowering eligible background-app priority. Nothing is quit; your foreground app stays at normal priority.

- **Modes:** Automatic, Balanced, Gaming, Creator, Coding, Local AI. Automatic follows your work and adapts to sustained CPU pressure.
- **Four choices per app:** Boost, Normal, Yield, Eco. Your choice always beats the mode.
- **Advanced mode:** per-core load %, memory, swap and pressure, process counts, PIDs, timers, and why each rule applies.
- **Memory guard (System tab):** pressure, swap, and the apps using the most memory, with Hide and Quit (you choose; it asks
  first). Warns when swap grows during a boost.
- **Startup helpers (System tab):** the background helpers in your LaunchAgents folder, each with a reversible on/off switch.
- **Session reports:** when a boost ends, a measured summary drops out of the notch; Insights keeps recent ones as
  shareable image cards.
- **Rules per game:** while a game is boosted, switch the chips to "This game only" so Discord can be Eco for Roblox but
  Normal otherwise.
- **Battery-aware:** unplugged, apps working hard in the background move to the efficiency cores even without a boost.
- **Automation:** `coremium://mode/gaming`, `coremium://pause`, `coremium://open/storage`, `Coremium --mode coding` from
  Terminal, and Shortcuts actions (Set Coremium mode, Pause, Resume).
- **Updates:** a daily check for a newer version, installed in one click after the download's checksum is verified.
- **Live notch:** during a boost the notch ears become a tiny live meter (performance-core load on the left, apps moved
  aside on the right), and each decision drops out of the notch for three seconds. Clicks pass through; turn it off in Settings.
- **Storage:** see what's filling your disk (app caches, logs, Xcode build files, old downloads, the Trash) and move what you
  choose to the Trash. Read-only scan, nothing is ever deleted for good, documents are never touched.
- **Insights:** what Coremium actually did (measured), why it made each decision, and what it costs.
- **Simulate:** an animated illustration of the idea (clearly labelled as such).
- **Learns locally:** suggests "Yield" for apps that hog the CPU while you play, and "Boost" for apps you work hard in.
- **Fullscreen fix** for the macOS 27 fullscreen stutter on 120 Hz MacBooks (optional).
- A short first-launch screen shows real activity immediately; the full welcome tour is optional. Free, open source
  (MIT), no account, no telemetry. Its only network request is a daily update check you can turn off.

> Not affiliated with Apple. The Apple logo on the chip is Apple's own system symbol, drawn by macOS at runtime to
> indicate Apple Silicon. Coremium doesn't ship it.

## How it works, and what it can't do

macOS lets any app lower the priority of its **own user's** processes. Processes in the *background band* get lower CPU
priority and throttled disk and network I/O, favoring the **efficiency cores** on Apple Silicon. That is what
`taskpolicy -b` does, and what Coremium does
for you, automatically and reversibly.

**"Boost" is therefore indirect.** macOS has no public way to raise an app above normal priority or pin it to the
performance cores without root. Boosting an app means *protecting it and moving other apps aside while you use it*.

**Does it help? It depends on load.** When your Mac has more busy work than cores, background apps compete with your
game and cause hitches; moving them to the efficiency cores removes that contention. When your Mac isn't overloaded
there is nothing to fix. Coremium shows only what it can measure: how long it protected your app, how many processes it
moved, its own CPU cost, and a plain-words log of each decision. It makes no battery, temperature or speed-up claims.

**GPU.** macOS has no public way to give one app GPU priority or to slow another app's GPU work. Coremium measures
instead: device GPU load and each app's share of GPU time (read from the system registry, no admin rights), shows
"GPU heavy" on rows, and names heavy background users in its decision line. We tested whether the background priority
band reduces GPU contention with a Metal frame-loop (`bench/gpu-contention.swift`): it did not (median frame time
2.1 ms with a GPU hog at normal priority, 2.4 ms with the hog in the background band, no hitches in either), so
Coremium does not pretend it does.

Coremium does **not**: touch other users' or system processes (no root helper), control clock speed, measure power or
exact temperature (so it never claims longer battery life or lower temperature; the energy figure in Insights is a
labelled estimate), attribute helper services macOS starts for an app (e.g. Safari web content), or quit/suspend anything.
On Intel Macs there are no efficiency cores; demoted apps simply get lower priority.

## Modes

| Mode | Protected (boost) | Lower-priority background work during a session |
|---|---|---|
| **Automatic** | Follows the app in front, or a busy game/creator/AI app | Busy eligible apps under sustained CPU pressure; preserves busy builds, renders and local models |
| **Gaming** | Games | Creative tools, dev tools, browsers, chat, AI assistants |
| **Creator** | Video, audio, 3D, design, photo | Games, browsers, chat, AI assistants |
| **Coding** | Editors, terminals, builds | Games, creative tools |
| **Local AI** | LLMs, image generation, VMs | Games, creative tools, browsers, chat |
| **Balanced** | Nothing automatic | Nothing; only your per-app choices |

Per-app choices: **Boost** (protected, starts sessions), **Normal** (untouched), **Yield** (steps aside during
sessions), **Eco** (always on efficiency cores unless you're using it). A session ends 90 seconds after the boosted app
isn't in use. Finder, Dock, Music, Spotify and Coremium itself are protected.

Apps are recognised by kind (a built-in table, the category each app declares, Steam library location, and names of
common local-AI tools). Coremium reads your apps directly and watches your app folders, so it never waits on Spotlight.

### Adaptive Automatic

Automatic uses local measurements, not a cloud model. During a protected session it waits for sustained high CPU load
before lowering the priority of busy background apps. It restores those changes after sustained relief instead of
switching back and forth on every sample. Foreground apps, protected apps and busy developer/creative/local-AI work
are excluded. Your explicit per-app and per-game choices still win; Pause and Quit restore scheduling as before.

The initial policy requires average performance-core load of at least 80% for six seconds (all cores on Intel), with
eligible background apps using at least 25% of one core for six seconds. Recovery requires load at or below 55% for
12 seconds, a minimum 15-second hold, then a 10-second cooldown. Sampling cadence means decisions can take longer
than these minimums. Missing measurements or a long sampling gap release adaptive selections safely.

Disable **Adapt Automatic to CPU pressure** in Settings to return to category-based Automatic. Existing explicit
Yield/Eco rules, the optional heavy-app catcher and battery-saving rules are separate controls; this adaptive policy
does not override them. GPU and memory readings remain advisory: it does not claim to optimize GPU priority, free
memory, or guarantee a speed-up. Learning suggestions still require your approval.

### Coremium's own resource budget

Application events trigger immediate evaluation; one coalesced timer catches background changes. The source build
does not poll while paused with the panel closed. Normal cadence is ten seconds idle, four seconds during a session,
and two seconds while the panel is open. Low Power Mode slows those to 20, six and three seconds respectively.
Adaptive CPU decisions reuse this loop rather than starting another one.

Global memory/GPU diagnostics refresh at most every 12 seconds during a closed session, or every four seconds while
visible; detailed per-process memory footprints are visible-only and refresh at most every six seconds. Low Power
Mode slows diagnostics further. App indexing is cached and refreshed by filesystem events, not repeated every tick.
The installed-app list is rebuilt only after indexing or rule changes. Idle ticks do not continually update history.

Use the read-only engine profiler below to measure overhead on your own machine. It isolates settings and cannot
change other apps' priorities. This measures the engine, not native UI drawing, and is not a workload speed benchmark.

## Known limitations

- Boost is indirect (see above); Coremium can't raise an app above normal priority.
- Helper services that macOS starts for an app (Safari web content, etc.) can't be attributed to it.
- No battery-life or temperature claims; it can't measure either.
- Ad-hoc signed and not notarized, so macOS asks you to approve it once.

## Tested on

| macOS | Hardware | Status |
|---|---|---|
| 27.0.1 | MacBook Pro 14", M3 Pro | Developed and tested here |
| 13 to 26, Intel, other Apple chips | | Built for these (deployment target 13.0, universal) but not tested yet. Please report. |

## Windows (beta)

A desktop version for Windows 10 and 11 lives in [`windows/`](windows/). It uses Windows efficiency mode instead of the
notch, and is a **beta**: not yet tested by hand on a Windows PC. Install it from PowerShell (checks the checksum, no
admin, no SmartScreen prompt):
`irm https://raw.githubusercontent.com/Cubinghackerz/Coremium/master/scripts/install.ps1 | iex`
or download it from the [Windows beta release](../../releases?q=windows&expanded=true).

## Install

No paid Apple developer account is needed, so the app is **ad-hoc signed, not notarized**; macOS warns the first time.

1. Download the Mac DMG from [Releases](../../releases), open it and drag **Coremium** to Applications.
2. Open it. For an unidentified-developer warning, use **System Settings › Privacy & Security › Open Anyway** after
   trying to open it, then confirm Open. See [Apple's approval instructions](https://support.apple.com/en-au/102445).
   A warning that the app is damaged or will damage your computer is different: stop and report the exact message.
3. Automatic is enabled by default. The source build's short first-launch screen shows actual activity; the longer
   tour is optional (published v2.0.1 still has the earlier tour). Hover the notch or click the menu-bar chip icon.
   While a game is in
   front the pill ignores the mouse so it never gets in the way; use the menu-bar icon then.

Supports **macOS 13 through 27**, Apple Silicon and Intel (universal binary). Developed and tested on macOS 27 / M3 Pro;
other versions are built against the macOS 13 target but not individually tested yet. Reports are welcome.

Prefer Terminal? First [inspect the installer](scripts/install.sh). It verifies the downloaded checksum and removes
quarantine, so it bypasses the normal first-launch approval. Only use it if you trust that behavior:

```bash
curl -fsSL https://raw.githubusercontent.com/Cubinghackerz/Coremium/master/scripts/install.sh | bash
```

### If something stays slow

Quitting restores everything, as does the next launch after a crash. From Terminal:

```bash
/Applications/Coremium.app/Contents/MacOS/Coremium --restore-all
```

## The fullscreen fix

On 120 Hz ProMotion MacBooks, fullscreen Metal apps use Direct-to-Display, which breaks frame pacing; macOS 27 makes it
worse. Any other window on screen makes macOS composite normally. With the fix on, Coremium adds a 2-pixel always-on-top
window (invisible inside the notch; one dark pixel in the corner elsewhere), but only on a display that is showing a
fullscreen app, and removes it when the app leaves fullscreen. Ordinary and maximized windows are left alone, so moving,
tiling and resizing them feels exactly like stock macOS. It reads only window positions (no Screen Recording permission),
ignores clicks and never takes focus. Fullscreen video may use slightly more battery.

## Uninstall

Quit Coremium from its menu-bar icon, delete `Coremium.app`, and remove `~/Library/Application Support/Coremium`
(settings, history, crash-recovery file) and the login item in System Settings › General › Login Items if enabled.

## Build from source

```bash
brew install xcodegen
scripts/build.sh            # universal, ad-hoc signed app + zip in dist/
xcodebuild -project Coremium.xcodeproj -scheme CoremiumCore test
scripts/render-previews.sh out/   # renders every panel/tab/onboarding step to PNGs without launching the app
scripts/render-previews.sh --test-notch # native panel lifecycle regressions, isolated from real settings
scripts/render-previews.sh --profile-engine # read-only idle/active/paused/visible engine CPU and footprint samples
```

`Sources/CoremiumCore` holds all logic (process tree, priority control, rules, modes, classification, usage history,
learning, chip info) and is unit tested without launching the app. `Sources/Coremium` is the notch UI.

## License

MIT. See [LICENSE](LICENSE).
