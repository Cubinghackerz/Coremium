# Contributing

```bash
brew install xcodegen
xcodegen                                               # regenerates Coremium.xcodeproj from project.yml
xcodebuild -project Coremium.xcodeproj -scheme CoremiumCore test
scripts/build.sh                                       # universal ad-hoc app + zip in dist/
scripts/render-previews.sh out/                        # renders every tab to PNG without launching the app
```

- All logic lives in `Sources/CoremiumCore` and is unit tested; keep UI code in `Sources/Coremium` thin.
- Never claim what can't be measured (battery life, temperature, "X% faster"). Evidence comes from the measured usage ledger and
  the usage ledger.
- Only touch the current user's processes, and keep every change reversible (`DemotionLedger`).
- Tested on macOS 27 / M3 Pro only so far. Reports and fixes for other versions and chips are very welcome.
