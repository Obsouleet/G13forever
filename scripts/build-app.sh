#!/bin/bash
# Baut die Menüleisten-App als build/G13forever.app.
#
#   scripts/build-app.sh            Release-Build, ad-hoc signiert
#   SIGN_IDENTITY="Apple Development: …" scripts/build-app.sh
#                                   mit eigenem Zertifikat signieren, dann bleiben
#                                   die macOS-Freigaben auch nach neuen Builds erhalten
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product G13App
BIN="$(swift build -c release --show-bin-path)"

APP=build/G13forever.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/G13App" "$APP/Contents/MacOS/G13forever"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"

echo "Fertig: $APP"
echo "Starten mit: open $APP"
