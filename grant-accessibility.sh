#!/bin/bash
# Open the Accessibility pane so you can tick "iPad Keyboard".
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
cat <<'MSG'

In the window that just opened:
  1. find "MacSpace" in the list (it added itself on first launch)
  2. turn its switch ON
  3. no restart needed — it re-checks on every request

Verify with:  curl -s http://127.0.0.1:8787/health     → "ax": true  means ready
MSG
