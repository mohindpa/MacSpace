#!/bin/bash
# Does the bridge really toggle Caps Lock now?
set -u
TOKEN=$(cat ~/ipad-keyboard/token)
B="http://127.0.0.1:8787"
caps(){ curl -s "$B/ping?t=$TOKEN" | python3 -c "import sys,json;print('caps=' + str(json.load(sys.stdin).get('caps')))"; }
typeit(){ curl -s -X POST "$B/text?t=$TOKEN" -H 'Content-Type: application/json' -d "{\"s\":\"$1\",\"mode\":\"type\"}" >/dev/null; }
tapcaps(){ curl -s -X POST "$B/key?t=$TOKEN" -H 'Content-Type: application/json' -d '{"k":"capslock"}' ; echo; }
text(){ osascript -e 'tell application "TextEdit" to get text of front document'; }

osascript -e 'tell application "TextEdit"
  activate
  make new document
end tell' >/dev/null 2>&1
sleep 1.5
FRONT=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')
if [ "$FRONT" != "TextEdit" ]; then echo "ABORT: $FRONT is frontmost, not TextEdit"; exit 1; fi

echo "state at start: $(caps)"
typeit "1abc"; sleep 0.5
echo "after typing 1abc : [$(text)]   $(caps)"

echo "-> tap caps lock"; tapcaps; sleep 0.4
echo "   $(caps)"
typeit "2abc"; sleep 0.5
echo "after typing 2abc : [$(text)]   $(caps)"

echo "-> tap caps lock again"; tapcaps; sleep 0.4
echo "   $(caps)"
typeit "3abc"; sleep 0.5
echo "after typing 3abc : [$(text)]   $(caps)"

RESULT=$(text)
if [ "$RESULT" = "1abc2ABC3abc" ]; then echo; echo "PASS ✅ caps lock toggles on and off, letters respect it"; else echo; echo "FAIL ❌ got [$RESULT] expected [1abc2ABC3abc]"; fi

# leave caps off no matter what
curl -s "$B/key?t=$TOKEN" -H 'Content-Type: application/json' -d '{"k":"capslock"}' >/dev/null 2>&1
STATE=$(caps)
[ "$STATE" = "caps=False" ] || curl -s -X POST "$B/key?t=$TOKEN" -H 'Content-Type: application/json' -d '{"k":"capslock"}' >/dev/null
echo "caps left as: $(caps)"
osascript -e 'tell application "TextEdit" to close front document without saving' >/dev/null 2>&1
