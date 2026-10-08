#!/bin/bash
# usage: macterm.sh <outfile.png> <scriptfile>   -- runs the script in a fresh Terminal window, captures that window only, closes it
OUT="$1"; SCRIPT="$2"
if pgrep -x Terminal >/dev/null && [ "$(osascript -e 'tell application "Terminal" to count of windows')" != 0 ]; then echo "Terminal already has windows; refusing"; exit 1; fi
osascript >/dev/null <<AS
tell application "Terminal"
  activate
  do script "clear; bash $SCRIPT; echo; echo '--- done ---'"
  set bounds of front window to {60, 60, 1260, 820}
end tell
AS
for i in $(seq 1 60); do sleep 2; busy=$(osascript -e 'tell application "Terminal" to get busy of front window' 2>/dev/null); [ "$busy" = false ] && break; done
sleep 2
W=$(/tmp/winid Terminal); screencapture -x -o -l$W "$OUT"
osascript -e 'tell application "Terminal" to close front window saving no' >/dev/null 2>&1
sleep 1; osascript -e 'tell application "Terminal" to quit' >/dev/null 2>&1; echo "saved $OUT"
