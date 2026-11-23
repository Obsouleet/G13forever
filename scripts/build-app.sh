#!/bin/bash
# Baut die Menüleisten-App als build/G13forever.app.
#
#   scripts/build-app.sh            Release-Build, ad-hoc signiert
#   SIGN_IDENTITY="Apple Development: …" scripts/build-app.sh
#                                   mit eigenem Zertifikat signieren, dann bleiben
#                                   die macOS-Freigaben auch nach neuen Builds erhalten
#
# Für den Download (.github/workflows/release.yml):
#   UNIVERSAL=1                     für Apple silicon und Intel bauen
#   VERSION=1.2.3                   Versionsnummer statt der aus Info.plist
#   ZIP=1                           zusätzlich build/G13forever.zip erzeugen
set -euo pipefail
cd "$(dirname "$0")/.."

ARGS=(-c release)
if [[ "${UNIVERSAL:-}" == 1 ]]; then
    ARGS+=(--arch arm64 --arch x86_64)
fi
swift build "${ARGS[@]}" --product G13App
BIN="$(swift build "${ARGS[@]}" --show-bin-path)"

APP=build/G13forever.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/G13App" "$APP/Contents/MacOS/G13forever"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Sources/G13Kit/Resources/*.svg "$APP/Contents/Resources/"
# Englisch steht im Code, die Übersetzungen in Resources/<Sprache>.lproj.
cp -R Resources/*.lproj "$APP/Contents/Resources/"
# Die MIT-Lizenzen verlangen, dass ihre Texte auch der fertigen App beiliegen.
cp LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
if [[ -n "${VERSION:-}" ]]; then
    plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
    plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"
fi
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
codesign --verify --strict "$APP"

if [[ "${UNIVERSAL:-}" == 1 ]]; then
    for arch in arm64 x86_64; do
        lipo "$APP/Contents/MacOS/G13forever" -verify_arch "$arch"
    done
fi

echo "Done: $APP"
if [[ "${ZIP:-}" == 1 ]]; then
    rm -f build/G13forever.zip
    # ditto statt zip, damit die Signatur das Packen übersteht.
    ditto -c -k --keepParent "$APP" build/G13forever.zip
    echo "Done: build/G13forever.zip"
fi
echo "Start it with: open $APP"
