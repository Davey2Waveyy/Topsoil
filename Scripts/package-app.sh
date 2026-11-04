#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Topsoil"
APP="$ROOT/build/${APP_NAME}.app"
DMG="$ROOT/build/${APP_NAME}.dmg"
BIN_SRC="$ROOT/.build/release/Topsoil"
VERSION="${1:-0.1.0}"

echo "==> swift build -c release"
swift build -c release --package-path "$ROOT"

echo "==> assembling bundle"
rm -rf "$APP" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_SRC" "$APP/Contents/MacOS/Topsoil"
cp "$ROOT/THIRD_PARTY_LICENSES.md" "$APP/Contents/Resources/THIRD_PARTY_LICENSES.md"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Topsoil</string>
  <key>CFBundleDisplayName</key><string>Topsoil</string>
  <key>CFBundleIdentifier</key><string>io.notchapple.NotchApple</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleExecutable</key><string>Topsoil</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSCalendarsUsageDescription</key>
  <string>Topsoil shows your upcoming events in the notch.</string>
  <key>NSCalendarsFullAccessUsageDescription</key>
  <string>Topsoil shows your upcoming events in the notch.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Topsoil controls Music and Spotify playback from the notch.</string>
</dict>
</plist>
PLIST

echo "==> ad-hoc codesign"
codesign --force --deep --sign - \
  --entitlements "$ROOT/Topsoil.entitlements" "$APP"

echo "==> creating DMG"
STAGING="$ROOT/build/_dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -r "$APP" "$STAGING/Topsoil.app"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "Topsoil" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$DMG" > /dev/null

rm -rf "$STAGING"

echo "==> done: $DMG"
