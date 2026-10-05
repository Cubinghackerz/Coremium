#!/bin/zsh
# Renders the app's views to PNGs for layout checks. Never launches Coremium. Usage: scripts/render-previews.sh <folder>
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-build/previews}"
T="$(mktemp -d)"
export COREMIUM_DATA_DIR="$(mktemp -d)"
# 1. the core as its own module (the app imports it)
swiftc -emit-library -emit-module -module-name CoremiumCore -O -o "$T/libCoremiumCore.dylib" \
  -Xlinker -install_name -Xlinker "$T/libCoremiumCore.dylib" Sources/CoremiumCore/*.swift -framework IOKit
# 2. app views + the renderer
SOURCES=($(find Sources/Coremium -name '*.swift' ! -name CoremiumApp.swift) scripts/render-previews.swift)
swiftc -parse-as-library -D PREVIEW -O -I "$T" -L "$T" -lCoremiumCore -o "$T/render-previews" "${SOURCES[@]}"
"$T/render-previews" "$OUT"
