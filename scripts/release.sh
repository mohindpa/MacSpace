#!/bin/bash
# Build, sign, notarize, and package a MacSpace release.
#
# Required environment variables:
#   SIGNING_IDENTITY  Developer ID Application certificate name
#   NOTARY_PROFILE    notarytool keychain profile name
# Optional:
#   BUILD_NUMBER      monotonically increasing bundle build number (default: 1)
#   DIST_DIR          release output directory (default: dist)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=${1:-$(tr -d '[[:space:]]' < VERSION)}
VERSION=${VERSION#v}
EXPECTED_VERSION=$(tr -d '[[:space:]]' < VERSION)
SOURCE_VERSION=$(sed -nE 's/^let VERSION = "([^"]+)"/\1/p' src/main.swift)
BUILD_NUMBER=${BUILD_NUMBER:-1}
DIST_DIR=${DIST_DIR:-dist}
SIGNING_IDENTITY=${SIGNING_IDENTITY:-}
NOTARY_PROFILE=${NOTARY_PROFILE:-}

fail() { echo "error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"; }

for command in codesign ditto hdiutil shasum spctl xcrun; do need "$command"; done
[ -n "$SIGNING_IDENTITY" ] || fail "set SIGNING_IDENTITY to your Developer ID Application certificate"
[ -n "$NOTARY_PROFILE" ] || fail "set NOTARY_PROFILE to your notarytool keychain profile"
[ "$VERSION" = "$EXPECTED_VERSION" ] || fail "release version ($VERSION) must match VERSION ($EXPECTED_VERSION)"
[ "$VERSION" = "$SOURCE_VERSION" ] || fail "release version ($VERSION) must match src/main.swift ($SOURCE_VERSION)"

APP_BUILD_DIR=build/release
APP="$APP_BUILD_DIR/MacSpace.app"
STAGING_DIR="$APP_BUILD_DIR/dmg-root"
NOTARY_ZIP="$APP_BUILD_DIR/MacSpace-$VERSION-notary.zip"
ZIP="$DIST_DIR/MacSpace-$VERSION-macos.zip"
DMG="$DIST_DIR/MacSpace-$VERSION.dmg"

rm -rf "$APP_BUILD_DIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "→ building universal app"
ARCHS="arm64 x86_64" BUILD_DIR="$APP_BUILD_DIR" BUILD_NUMBER="$BUILD_NUMBER" \
  SIGNING_IDENTITY="$SIGNING_IDENTITY" ./build.sh

echo "→ verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dvv "$APP" 2>&1 | grep -q "Runtime Version" || fail "hardened runtime is missing"

echo "→ submitting app for notarization"
ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "→ creating release archives"
ditto -c -k --keepParent "$APP" "$ZIP"
mkdir -p "$STAGING_DIR"
cp -R "$APP" "$STAGING_DIR/MacSpace.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "MacSpace" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG"

echo "→ notarizing DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl -a -vvv -t open "$APP"
spctl -a -vvv -t open "$DMG"

shasum -a 256 "$ZIP" "$DMG" > "$DIST_DIR/SHA256SUMS.txt"
rm -rf "$STAGING_DIR" "$NOTARY_ZIP"

echo "✓ release ready in $DIST_DIR"
