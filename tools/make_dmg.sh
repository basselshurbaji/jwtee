#!/bin/bash
# Builds a Release .app and packages it into dist/JWTee.dmg with a
# drag-to-Applications layout. Uses whatever signing the project is set to.
set -euo pipefail
cd "$(dirname "$0")/.."

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
DERIVED=.build-xcode
APP="$DERIVED/Build/Products/Release/jwtee.app"

xcodebuild -project jwtee.xcodeproj -scheme jwtee \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED" build >/dev/null

STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/JWTee.app"
ln -s /Applications "$STAGE/Applications"

mkdir -p dist
rm -f dist/JWTee.dmg
hdiutil create -volname "JWTee" -srcfolder "$STAGE" \
    -ov -format UDZO dist/JWTee.dmg >/dev/null
rm -rf "$STAGE"

echo "created dist/JWTee.dmg ($(du -h dist/JWTee.dmg | cut -f1))"
