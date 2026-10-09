#!/usr/bin/env bash
# Live frames of the iPhone Mirroring window (window only), one every 4 s, skipping frames identical to the previous one.
# usage: tools/live-shots.sh <dir> [minutes=15]     Files are <dir>/HHMMSS.png (UTC). Review and delete private frames after.
HERE="$(cd "$(dirname "$0")" && pwd)"; DIR="${1:?usage: live-shots.sh dir [minutes]}"; END=$(( $(date +%s) + ${2:-15} * 60 ))
mkdir -p "$DIR"; last=""
while [ "$(date +%s)" -lt "$END" ]; do
  WID=$(swift "$HERE/screens/winid.swift" "iPhone Mirroring" 2>/dev/null) || { sleep 4; continue; }
  f="$DIR/$(date -u +%H%M%S).png"
  screencapture -x -o -l"$WID" "$f" || { sleep 4; continue; }
  h=$(md5 -q "$f"); [ "$h" = "$last" ] && rm -f "$f" || last="$h"
  sleep 4
done
echo "done: $(ls "$DIR" | wc -l | tr -d ' ') frames in $DIR"
