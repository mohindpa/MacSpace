#!/bin/bash
# Start the bridge in the background and print the iPad URL.
set -e
cd "$(dirname "$0")"

APP="build/MacSpace.app"
BIN="$APP/Contents/MacOS/MacSpace"
TOKEN=$(cat token 2>/dev/null || echo "")

if [ ! -x "$BIN" ]; then
  echo "not built yet — run ./build.sh first"; exit 1
fi

pkill -f "MacSpace" 2>/dev/null || true
sleep 0.3

# Launch as a real .app so macOS attributes the Accessibility permission to it.
open -n "$APP" --args --port 8787 --dir "$PWD"

sleep 1
IP=$(ipconfig getifaddr en0 2>/dev/null || echo "localhost")
TOKEN=$(cat token 2>/dev/null || echo "?")
echo
echo "MacSpace is running."
echo "  Open in Safari on your iPad:  http://$IP:8787/?t=$TOKEN"
echo "  Log: tail -f server.log"
echo
grep -E "ACCESSIBILITY|open on iPad" server.log | tail -3
