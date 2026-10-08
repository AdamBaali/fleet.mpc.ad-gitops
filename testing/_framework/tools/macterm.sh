#!/bin/bash
# usage: macterm.sh <outfile.png> <scriptfile>
# Opens a NEW Terminal window, runs the script, captures only that window (its AppleScript window id is its CGWindowID), then closes only that window.
OUT="$1"; SCRIPT="$2"
WID=$(osascript <<AS
tell application "Terminal"
  activate
  do script "clear; bash $SCRIPT; echo; echo '--- done ---'"
  set bounds of front window to {60, 60, 1260, 820}
  return id of front window
end tell
AS
)
for i in $(seq 1 90); do sleep 2; busy=$(osascript -e "tell application \"Terminal\" to get busy of window id $WID" 2>/dev/null); [ "$busy" = false ] && break; done
sleep 2
screencapture -x -o -l$WID "$OUT"
osascript -e "tell application \"Terminal\" to close window id $WID saving no" >/dev/null 2>&1
echo "saved $OUT (window $WID)"
