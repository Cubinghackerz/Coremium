#!/bin/bash
# Installs the latest Coremium release into /Applications. Usage:
#   curl -fsSL https://raw.githubusercontent.com/Cubinghackerz/Coremium/master/scripts/install.sh | bash
# It downloads the release zip, checks its SHA-256 against the published checksum, quits a running Coremium,
# and copies the app. Files fetched by curl aren't quarantined, so macOS doesn't show the first-launch warning.
set -euo pipefail
REPO="Cubinghackerz/Coremium"
[ "$(uname)" = "Darwin" ] || { echo "Coremium is for macOS."; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

echo "Finding the latest release…"
JSON="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")"
ZIP_URL="$(printf '%s' "$JSON" | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -1 | sed 's/.*"\(http[^"]*\)"/\1/')"
SUM_URL="$(printf '%s' "$JSON" | grep -o '"browser_download_url": *"[^"]*\.sha256"' | head -1 | sed 's/.*"\(http[^"]*\)"/\1/')"
[ -n "$ZIP_URL" ] && [ -n "$SUM_URL" ] || { echo "No release found at github.com/$REPO/releases"; exit 1; }

ZIP="$TMP/$(basename "$ZIP_URL")"
curl -fsSL "$ZIP_URL" -o "$ZIP"
curl -fsSL "$SUM_URL" -o "$TMP/sums.txt"
EXPECTED="$(grep " $(basename "$ZIP")\$" "$TMP/sums.txt" | awk '{print $1}')"
ACTUAL="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
[ -n "$EXPECTED" ] && [ "$EXPECTED" = "$ACTUAL" ] || { echo "Checksum mismatch. Nothing was installed."; exit 1; }
echo "Checksum OK."

pkill -TERM -x Coremium 2>/dev/null && sleep 2 || true   # quitting restores every app it moved
ditto -x -k "$ZIP" "$TMP/out"
rm -rf /Applications/Coremium.app
ditto "$TMP/out/Coremium.app" /Applications/Coremium.app
open -a /Applications/Coremium.app
echo "Coremium is installed. Hover the notch (or click the chip icon in the menu bar) to open it."
