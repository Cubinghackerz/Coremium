#!/bin/zsh
# Builds a universal (arm64 + x86_64), ad-hoc signed Coremium.app and zips it to dist/.
# No Apple Developer account needed. Usage: scripts/build.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-$(grep -m1 MARKETING_VERSION project.yml | sed 's/.*"\(.*\)".*/\1/')}"

command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen"; exit 1; }
xcodegen generate
rm -rf build/Release dist
xcodebuild -project Coremium.xcodeproj -scheme Coremium -configuration Release \
  -derivedDataPath build/Release CODE_SIGN_IDENTITY=- build

APP="build/Release/Build/Products/Release/Coremium.app"
codesign --verify --deep --strict "$APP"
mkdir -p dist
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/Coremium-$VERSION.zip"

# Disk image: the app, a shortcut to /Applications, and a note about the first launch.
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/Coremium.app"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/If macOS blocks it.txt" <<'NOTE'
Coremium is free and open source, signed ad hoc (no paid Apple developer account), so macOS asks once.

1. Drag Coremium onto Applications, then open it.
2. If macOS says it can't verify the app: System Settings > Privacy & Security > "Open Anyway".
   Or in Terminal:  xattr -dr com.apple.quarantine /Applications/Coremium.app

Source and checksums: https://github.com/Cubinghackerz/Coremium
NOTE
hdiutil create -quiet -volname "Coremium" -srcfolder "$STAGE" -ov -format UDZO "dist/Coremium-$VERSION.dmg"
rm -rf "$STAGE"
( cd dist && shasum -a 256 "Coremium-$VERSION.zip" "Coremium-$VERSION.dmg" | tee "Coremium-$VERSION.sha256" )
echo "Built dist/Coremium-$VERSION.zip and .dmg (archs: $(lipo -archs "$APP/Contents/MacOS/Coremium"))"
