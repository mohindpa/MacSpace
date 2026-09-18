#!/bin/bash
# Build the MacSpace macOS app bundle. Set SIGNING_IDENTITY to a Developer ID
# certificate name to produce a hardened, distributable app.
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(tr -d '[[:space:]]' < VERSION)
BUILD_NUMBER=${BUILD_NUMBER:-1}
BUILD_DIR=${BUILD_DIR:-build}
APP="$BUILD_DIR/MacSpace.app"
SIGNING_IDENTITY=${SIGNING_IDENTITY:--}
ARCHS=${ARCHS:-$(uname -m)}

if ! [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "VERSION must look like 1.2.3 (found: $VERSION)" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ compiling MacSpace ${VERSION} for ${ARCHS}…"
read -r -a ARCH_LIST <<< "$ARCHS"
ARCH_BINARIES=()
for ARCH in "${ARCH_LIST[@]}"; do
  ARCH_BINARY="$APP/Contents/MacOS/MacSpace-$ARCH"
  swiftc -O -swift-version 5 -target "$ARCH-apple-macosx13.0" \
    -o "$ARCH_BINARY" src/main.swift
  ARCH_BINARIES+=("$ARCH_BINARY")
done

if [ "${#ARCH_BINARIES[@]}" -eq 1 ]; then
  mv "${ARCH_BINARIES[0]}" "$APP/Contents/MacOS/MacSpace"
else
  lipo -create "${ARCH_BINARIES[@]}" -output "$APP/Contents/MacOS/MacSpace"
  rm -f "${ARCH_BINARIES[@]}"
fi

cp macos/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
cp -R web "$APP/Contents/Resources/web"

if [ "$SIGNING_IDENTITY" = "-" ]; then
  echo "→ ad-hoc signing (development build)…"
  codesign --force --sign - --identifier net.websitespa.macspace "$APP"
else
  echo "→ signing with Developer ID…"
  codesign --force --options runtime --timestamp \
    --sign "$SIGNING_IDENTITY" --identifier net.websitespa.macspace "$APP"
fi

echo "✓ built: $APP"
