#!/bin/bash
# Start MacSpace and print the URL for the iPad.
# Source of truth = this folder (in Documents); the running copy is staged into
# ~/Library/Application Support/MacSpace so macOS never blocks it on a TCC prompt.
set -e
cd "$(dirname "$0")"

APP="build/MacSpace.app"
BIN="$APP/Contents/MacOS/MacSpace"
RUNTIME="$HOME/Library/Application Support/MacSpace"

if [ ! -x "$BIN" ]; then
  echo "not built yet — run ./build.sh first"; exit 1
fi

pkill -f "MacSpace --port" 2>/dev/null || true
sleep 0.3

# Stage the web app outside Documents: macOS blocks a LaunchServices-launched app
# that touches Documents on a consent dialog, and this helper reads its token at
# startup — it would hang before serving anything.
mkdir -p "$RUNTIME"
rm -rf "$RUNTIME/web"
cp -R "$PWD/web" "$RUNTIME/web"
if [ ! -f "$RUNTIME/token" ] && [ -f "$PWD/token" ]; then cp "$PWD/token" "$RUNTIME/token"; fi

# Launch as a real .app so macOS attributes the Accessibility permission to it.
open -n "$APP" --args --port 8787 --dir "$RUNTIME" --web "$RUNTIME/web"

sleep 1
IP=$(ipconfig getifaddr en0 2>/dev/null || echo "localhost")
TOKEN=$(cat "$RUNTIME/token" 2>/dev/null || cat token 2>/dev/null || echo "?")
echo
echo "MacSpace is running."
echo "  Open in Safari on your iPad:  http://$IP:8787/?t=$TOKEN"
echo "  Log: tail -f \"$RUNTIME/server.log\""
echo "  Source: $PWD  (staged into $RUNTIME to run)"
echo
grep -E "ACCESSIBILITY|open on iPad" "$RUNTIME/server.log" 2>/dev/null | tail -3
