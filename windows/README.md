# Coremium for Windows (beta)

A desktop version of Coremium for Windows 10 and 11 (x64). Same idea, no notch: while a game, creative app, dev tool or
local AI model is in front, background apps are moved into **Windows efficiency mode** (EcoQoS plus low priority, the same
thing Task Manager's "Efficiency mode" does). On hybrid CPUs (Intel 12th gen and later) that runs them on the efficiency
cores; on other CPUs they simply get lower priority. Nothing is closed.

- Modes: Automatic, Balanced, Gaming, Creator, Coding, Local AI. Per app: Boost, Normal, Yield, Eco.
- Plain-words decisions, Advanced numbers, Pause, tray icon, start with Windows (tray menu).
- Only your own apps, no admin rights, no network access. Settings, history and the crash-recovery file live in
  `%LOCALAPPDATA%\Coremium`. Quitting, pausing or `Coremium.exe --restore-all` puts everything back.

**Beta:** built and unit-tested on macOS with the .NET Windows targeting pack and on GitHub's Windows runner, but not yet
tested by hand on a Windows PC. The executable is not code-signed, so SmartScreen warns the first time
("More info" › "Run anyway"). Reports are welcome.

## Build
```bash
dotnet test tests/Coremium.Core.Tests
dotnet publish src/Coremium.App -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -o dist/win-x64
```
`src/Coremium.Core` is the shared, cross-platform logic (rules, modes, classifier, decisions); `src/Coremium.App` is the
WPF window, tray and the Windows scheduling backend.
