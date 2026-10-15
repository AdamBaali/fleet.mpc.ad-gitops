#!/usr/bin/env bash
# One-page status of the shared Mac lab, so a session working on one test can see what the others are using.
# Read-only. Usage: testing/_framework/bin/status.sh   (run from anywhere)
T="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
echo "== $(date '+%F %T')  project status files (each <project>/STATUS.md; the owning session updates its own)"
for f in "$T"/*/STATUS.md; do [ -f "$f" ] || continue; echo; echo "--- $(basename "$(dirname "$f")")"; sed -n '1,/^## Now/p' "$f" | cut -c1-200 | head -30; sed -n '/^## Now/,/^## /p' "$f" | sed '/^## [^N]/d' | head -6; done
echo; echo "== UTM virtual machines (name, state)"; /Applications/UTM.app/Contents/MacOS/utmctl list 2>/dev/null | awk 'NR>1{printf "  %-10s %s\n",$2,$3}' | sort | uniq -c | sed 's/^ *//' | head -20
echo; echo "== free disk"; df -h /System/Volumes/Data | tail -1 | awk '{print "  "$4" free of "$2}'
echo; echo "== listening lab ports (AirPlay 7000, SSH 22, dev servers)"; lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1 && ($9 ~ /:(7000|8000|8080|9032|22)$/){print "  "$1" "$9}' | sort -u | head -8
echo; echo "== latest commits per project folder"
for d in "$T"/*/; do n=$(basename "$d"); [ "${n:0:1}" = "_" ] && continue; printf '  %-28s ' "$n"; git -C "$T" log -1 --format='%ar: %s' -- "$n" 2>/dev/null | cut -c1-80; done
