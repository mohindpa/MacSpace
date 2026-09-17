#!/bin/bash
# Build the iPad Keyboard Bridge macOS app bundle.
set -e
cd "$(dirname "$0")"

APP="build/MacSpace.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ compiling…"
swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/MacSpace" src/main.swift

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>MacSpace</string>
  <key>CFBundleIdentifier</key><string>net.websitespa.macspace</string>
  <key>CFBundleName</key><string>MacSpace</string>
  <key>CFBundleDisplayName</key><string>MacSpace</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "→ signing (ad-hoc)…"
codesign --force --sign - --identifier net.websitespa.macspace "$APP" 2>/dev/null || echo "  (codesign skipped)"

echo "✓ built: $APP"
