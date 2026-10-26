#!/bin/bash
# Watches a host through a wipe: every 20 s logs the MDM command result, the VM's guest agent, and Fleet's view of the
# host; a window screenshot every 2 minutes. Exits when Fleet's last_enrolled_at changes, or after the timeout.
# Usage: tools/watch-reset.sh <test-id> <vm> <fleet host id> <command uuid> [timeout minutes]
set -u
ID="$1"; V="$2"; HID="$3"; CMD="$4"; T="${5:-75}"
export PATH=$HOME/.local/bin:$PATH
D=$(ls -d test-evidence/*/"$ID"-* | head -1); LOG="$D/timeline.txt"
first=$(fleetctl api /api/v1/fleet/hosts/$HID 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["host"]["last_enrolled_at"])')
echo "$(date -u +%FT%TZ) start; last_enrolled_at=$first" >> "$LOG"
end=$(( $(date +%s) + T*60 )); n=0
while [ "$(date +%s)" -lt "$end" ]; do
  r=$(fleetctl get mdm-command-results --id="$CMD" 2>/dev/null | grep -E 'Status|[0-9]{3}' | tr -s ' ' | head -3 | tr '\n' ' ')
  ga=$(tools/vm-exec.sh "$V" '"agent"' 15 2>/dev/null | grep -q agent && echo up || echo down)
  h=$(fleetctl api /api/v1/fleet/hosts/$HID 2>/dev/null | python3 -c 'import json,sys
h=json.load(sys.stdin)["host"]; m=h.get("mdm") or {}
print(h["status"], "seen", h["seen_time"], "enrolled", h["last_enrolled_at"], "mdm", m.get("enrollment_status"), "conn", m.get("connected_to_fleet"))' 2>/dev/null || echo "host lookup failed")
  echo "$(date -u +%FT%TZ) vm=$(/Applications/UTM.app/Contents/MacOS/utmctl status "$V" 2>/dev/null) agent=$ga | $h | cmd: $r" >> "$LOG"
  if [ $((n % 6)) -eq 0 ]; then tools/shot.sh "$ID" "t$(date -u +%H%M)" UTM "$V" >/dev/null 2>&1; fi
  n=$((n+1))
  echo "$h" | grep -q "enrolled $first" || { echo "$(date -u +%FT%TZ) last_enrolled_at changed" >> "$LOG"; tools/shot.sh "$ID" "reenrolled" UTM "$V" >/dev/null 2>&1; exit 0; }
  sleep 20
done
echo "$(date -u +%FT%TZ) timeout" >> "$LOG"
