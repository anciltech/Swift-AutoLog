#!/usr/bin/env bash
# Builds AutoLogSettings and launches it as a proper .app bundle.
#
# WHY: SPM executables have no Info.plist / CFBundleIdentifier.
# macOS routes TextField keyboard input through ViewBridge (XPC), which
# requires a bundle identifier to open its connection. Without one ViewBridge
# terminates and all TextFields are silently deaf — keystrokes go nowhere.
# Wrapping the binary in a minimal .app + Info.plist gives macOS the ID it
# needs and makes the text input system work correctly.
set -euo pipefail

cd "$(dirname "$0")"

echo "▶ Building AutoLogSettings…"
swift build --configuration debug --target AutoLogSettings

BINARY=".build/debug/AutoLogSettings"
APP="/tmp/AutoLogSettings.app"

# ── Build .app bundle structure ────────────────────────────────────────────
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp "$BINARY" "$APP/Contents/MacOS/AutoLogSettings"

cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>dev.autolog.settings</string>
  <key>CFBundleName</key>
  <string>AutoLog Settings</string>
  <key>CFBundleDisplayName</key>
  <string>AutoLog Settings</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>AutoLogSettings</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
</dict>
</plist>
PLIST

# ── Launch ─────────────────────────────────────────────────────────────────
echo "▶ Launching AutoLog Settings…"
open "$APP"
