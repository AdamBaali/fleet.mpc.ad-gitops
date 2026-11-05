#!/usr/bin/env bash
# Fleet server logs from Render for a test run's time window, cut to the lines about Android enrollment and profiles.
# The Android enrollment and policy messages are debug level in Fleet, so they appear only with FLEET_LOGGING_DEBUG=true
# on the Render service.
#
# Usage: server-logs.sh SINCE [UNTIL]          UTC times, for example 2026-11-05T09:30:00Z. UNTIL defaults to now.
# Needs the Render CLI logged in (render login) and RENDER_SERVICE_ID (the srv-... ID of the Fleet service).
# IP addresses are masked: this repo is public and the evidence doesn't need them.
set -euo pipefail
since="${1:?usage: server-logs.sh SINCE [UNTIL]}"; until="${2:-$(date -u +%FT%TZ)}"
: "${RENDER_SERVICE_ID:?set RENDER_SERVICE_ID in private/fleet.env}"

render logs --resources "$RENDER_SERVICE_ID" --start "$since" --end "$until" --direction forward \
  --limit 1000 --output json --confirm \
  | python3 -I -c '
import json, re, sys
raw = sys.stdin.read().strip()
logs = json.loads(raw) if raw else []
if isinstance(logs, dict):
    logs = logs.get("logs") or logs.get("items") or []
keep = re.compile(r"android|enroll|pubsub|policy|policies|profile|clouddpc|amapi|devices/", re.I)
# Health checks and static assets fill the window without saying anything about the host.
drop = re.compile(r"/healthz|/assets/|GET /api/v1/fleet/version", re.I)
ip = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b|\b(?:[0-9a-f]{1,4}:){3,7}[0-9a-f]{1,4}\b", re.I)
n = 0
for l in logs:
    msg = l.get("message", "") if isinstance(l, dict) else str(l)
    ts = l.get("timestamp", "") if isinstance(l, dict) else ""
    if keep.search(msg) and not drop.search(msg):
        print(ts, ip.sub("<ip>", msg))
        n += 1
print("== %d matching lines of %d in the window (limit 1000)" % (n, len(logs)))
'
