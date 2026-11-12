#!/bin/bash
# Runs Fleet's Android profile job on demand every few seconds, so a newly enrolled host gets its
# per-host policy within seconds of enrollment and not up to 30 s later (the job's own schedule).
# Why: Android asks for the PIN in setup only if the policy lands during "Registering device...".
# Usage: tools/trigger-loop.sh [seconds between calls, default 2]. Stop with Ctrl-C.
# Needs private/fleet.env with FLEET_URL and FLEET_API_TOKEN (a global admin).
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . private/fleet.env; set +a
every="${1:-2}"
while true; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    -H "Authorization: Bearer $FLEET_API_TOKEN" \
    "$FLEET_URL/api/latest/fleet/trigger?name=mdm_android_profile_manager")
  echo "$(date -u +%H:%M:%S) trigger HTTP $code"
  sleep "$every"
done
