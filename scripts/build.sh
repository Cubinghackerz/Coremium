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
( cd dist && shasum -a 256 "Coremium-$VERSION.zip" | tee "Coremium-$VERSION.zip.sha256" )
echo "Built dist/Coremium-$VERSION.zip (archs: $(lipo -archs "$APP/Contents/MacOS/Coremium"))"
