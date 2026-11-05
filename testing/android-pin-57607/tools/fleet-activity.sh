#!/usr/bin/env bash
# Fleet's activity log for one Android host during a test run: the host's own activities, its upcoming activities,
# and global activities since SINCE that name the host (transfers and label changes appear there, not on the host).
# Fleet emits no enrollment activity for Android (NOTES.md), so enrollment shows up only in watch-host.sh.
#
# Usage: fleet-activity.sh SERIAL SINCE        SINCE is UTC, for example 2026-11-05T09:30:00Z
# Needs FLEET_URL and FLEET_API_TOKEN. Read-only.
set -euo pipefail
serial="${1:?usage: fleet-activity.sh SERIAL SINCE}"; since="${2:?usage: fleet-activity.sh SERIAL SINCE}"
: "${FLEET_URL:?set FLEET_URL}" "${FLEET_API_TOKEN:?set FLEET_API_TOKEN}"
get() { curl -sS --fail-with-body -H "Authorization: Bearer $FLEET_API_TOKEN" "${FLEET_URL%/}$1"; }
enc() { python3 -I -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }

host_id=$(get "/api/v1/fleet/hosts/identifier/$(enc "$serial")?exclude_software=true" \
  | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["host"]["id"])') \
  || { echo "no host with that serial in Fleet"; exit 1; }
echo "host id=$host_id, activities since $since"

# Prints one line per activity. Details are kept whole: they hold fleet names, label names and profile names, which
# is what the plan compares with the setup screens.
show() {
  python3 -I -c '
import json, sys
since, title = sys.argv[1], sys.argv[2]
host_id = int(sys.argv[3]) if len(sys.argv) > 3 else None
acts = json.load(sys.stdin).get("activities") or []
rows = []
for a in acts:
    if a.get("created_at", "") < since:
        continue
    det = a.get("details") or {}
    if host_id is not None:
        # Global feed: keep only activities that name this host.
        ids = set(det.get("host_ids") or []) | {det.get("host_id")}
        if host_id not in ids:
            continue
    rows.append("%s %s by %s %s" % (a.get("created_at"), a.get("type"),
                a.get("actor_full_name") or ("Fleet" if a.get("fleet_initiated") else "-"), json.dumps(det, sort_keys=True)))
print("== %s: %d" % (title, len(rows)))
print("\n".join(sorted(rows)))
' "$@"
}

get "/api/v1/fleet/hosts/$host_id/activities?per_page=100" | show "$since" "host activities"
get "/api/v1/fleet/hosts/$host_id/activities/upcoming?per_page=100" | show "" "upcoming host activities"
get "/api/v1/fleet/activities?per_page=200&order_key=created_at&order_direction=desc" | show "$since" "global activities naming the host" "$host_id"
