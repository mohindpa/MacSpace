#!/bin/bash
# End-to-end test: does a key event sent over HTTP really type on the Mac?
# Target: a brand new empty TextEdit document (closed afterwards, never saved).
# Uses digits so TextEdit's autocorrect can't confound the expectations.
set -u
TOKEN=$(cat ~/ipad-keyboard/token)
B="http://127.0.0.1:8787"
PASS=0; FAIL=0

say(){ printf '\n=== %s ===\n' "$1"; }
post(){ curl -s -X POST "$B$1?t=$TOKEN" -H 'Content-Type: application/json' -d "$2" >/dev/null; }
gettext(){ osascript -e 'tell application "TextEdit" to get text of front document' 2>&1; }
check(){ local label="$1" got; got=$(gettext); if [ "$got" = "$2" ]; then echo "PASS ✅  $label → [$got]"; PASS=$((PASS+1)); else echo "FAIL ❌  $label → got [$got] expected [$2]"; FAIL=$((FAIL+1)); fi; }

say "start real bridge on 8787"
pkill -f iPadKeyboard 2>/dev/null; sleep 0.5
nohup "$HOME/ipad-keyboard/build/iPad Keyboard.app/Contents/MacOS/iPadKeyboard" --port 8787 \
      --web "$HOME/ipad-keyboard/web" > /tmp/ipadkb-real.log 2>&1 &
sleep 2
curl -s "$B/health"; echo

say "open a scratch TextEdit document"
osascript -e 'tell application "TextEdit"
  activate
  make new document
end tell' >/dev/null 2>&1
sleep 1.5
FRONT=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>&1)
echo "frontmost app: $FRONT"
if [ "$FRONT" != "TextEdit" ]; then echo "ABORT: TextEdit is not frontmost — refusing to inject"; exit 1; fi

say "1. type digits through the bridge"
post /text '{"s":"1234","mode":"type"}'; sleep 0.8
check "plain typing" "1234"

say "2. Cmd+A (select all) then type over it — tests modifier injection"
post /key '{"k":"a","m":["cmd"],"d":"tap"}'; sleep 0.4
post /text '{"s":"5678","mode":"type"}'; sleep 0.8
check "cmd+A then retype" "5678"

say "3. two backspaces"
post /key '{"k":"delete","m":[],"d":"tap"}'; sleep 0.15
post /key '{"k":"delete","m":[],"d":"tap"}'; sleep 0.6
check "backspace x2" "56"

say "4. left,left then insert 9 at the start"
post /key '{"k":"left","m":[],"d":"tap"}'; sleep 0.15
post /key '{"k":"left","m":[],"d":"tap"}'; sleep 0.3
post /text '{"s":"9","mode":"type"}'; sleep 0.6
check "cursor left x2 + insert" "956"

say "5. Cmd+A then '42' (modifiers must not leak into the typed text)"
post /key '{"k":"a","m":["cmd"],"d":"tap"}'; sleep 0.3
post /text '{"s":"42","mode":"type"}'; sleep 0.6
check "no stale modifiers" "42"

say "6. Shift+Left selects a char, then type 8 over it"
post /key '{"k":"left","m":["shift"],"d":"tap"}'; sleep 0.3
post /text '{"s":"8","mode":"type"}'; sleep 0.6
check "shift+left then replace" "48"

say "7. unicode / emoji path"
post /key '{"k":"a","m":["cmd"],"d":"tap"}'; sleep 0.3
post /text '{"s":"héllo — ünïcode","mode":"type"}'; sleep 0.8
check "accents" "héllo — ünïcode"

say "cleanup"
osascript -e 'tell application "TextEdit" to close front document without saving' >/dev/null 2>&1
printf '\n================  %s passed, %s failed  ================\n' "$PASS" "$FAIL"
say "bridge log tail"
tail -12 /tmp/ipadkb-real.log
