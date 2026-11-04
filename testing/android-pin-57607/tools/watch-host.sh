#!/usr/bin/env bash
# Watches one Android host in Fleet during a test run and prints a line each time something changes:
# when the host first appears, its fleet, its labels, and each profile's status and detail.
# This gives the timeline to compare with the setup wizard screens (TEST-PLAN.md, "What to record").
#
# Usage: watch-host.sh SERIAL [seconds-to-watch, default 1800] [poll-interval, default 5]
# Needs FLEET_URL and FLEET_API_TOKEN in the environment. Read-only: it only sends GET requests.
# Start it before scanning the QR code. Times are UTC; "+mm:ss" is time since the watch started.
set -uo pipefail

serial="${1:?usage: watch-host.sh SERIAL [seconds] [interval]}"; limit="${2:-1800}"; every="${3:-5}"
: "${FLEET_URL:?set FLEET_URL}" "${FLEET_API_TOKEN:?set FLEET_API_TOKEN}"
start=$(date +%s); last=""
path="/api/v1/fleet/hosts/identifier/$(python3 -I -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1], safe=""))' "$serial")?exclude_software=true"

while [ $(( $(date +%s) - start )) -lt "$limit" ]; do
  body=$(curl -sS -H "Authorization: Bearer $FLEET_API_TOKEN" "${FLEET_URL%/}$path" 2>&1)
  state=$(echo "$body" | python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("no JSON from Fleet"); sys.exit()
h = d.get("host")
if not h:
    # 404 means not enrolled yet. Anything else (401, 403) is a setup problem, so show the message from Fleet.
    msg = d.get("message", "")
    print("host not in Fleet yet" if "not found" in msg.lower() else "Fleet error: " + msg); sys.exit()
mdm = h.get("mdm") or {}
fleet = h.get("fleet_name") or h.get("team_name") or "Unassigned"
labels = sorted(l["name"] for l in h.get("labels") or [] if l.get("label_type") != "builtin")
profs = sorted("%s=%s%s" % (p.get("name"), p.get("status"), (" (" + p["detail"] + ")") if p.get("detail") else "")
               for p in mdm.get("profiles") or [])
print("id=%s fleet=\"%s\" mdm=%s labels=%s profiles=[%s]" % (
    h.get("id"), fleet, mdm.get("enrollment_status"), ",".join(labels) or "-", "; ".join(profs) or "-"))
')
  if [ "$state" != "$last" ]; then
    e=$(( $(date +%s) - start ))
    printf '%s +%02d:%02d %s\n' "$(date -u +%FT%TZ)" $((e / 60)) $((e % 60)) "$state"
    last="$state"
  fi
  sleep "$every"
done
