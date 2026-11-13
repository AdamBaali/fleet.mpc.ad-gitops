#!/usr/bin/env bash
# Read-only Fleet API helper for test runs. It prints only the fields a test records, so saved output holds no IP
# addresses, users, or software lists that a public repo doesn't need.
#
# Usage: fleet-api.sh version
#        fleet-api.sh host <serial|uuid|hostname>     one host: OS, fleetd versions, fleet, MDM status, last seen
#        fleet-api.sh wait-host <id> [seconds]        polls every 5 s until the host exists (default 900 s)
#        fleet-api.sh activity <host id>              the host's activities, newest first
# Needs FLEET_URL and FLEET_API_TOKEN, from the environment or from the file in FLEET_ENV
# (default: ./private/fleet.env, the project's git-ignored file). Never print the token: run through ev_cmd, which masks it.
set -euo pipefail
env_file="${FLEET_ENV:-$PWD/private/fleet.env}"
[ -f "$env_file" ] && { set -a; . "$env_file"; set +a; }
: "${FLEET_URL:?set FLEET_URL (private/fleet.env)}" "${FLEET_API_TOKEN:?set FLEET_API_TOKEN (private/fleet.env)}"
get() { curl -sS --fail-with-body -H "Authorization: Bearer $FLEET_API_TOKEN" "${FLEET_URL%/}$1"; }
enc() { python3 -I -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }
host_json() { get "/api/v1/fleet/hosts/identifier/$(enc "$1")?exclude_software=true"; }

show_host() {
  python3 -I -c '
import json, sys
h = json.load(sys.stdin)["host"]
mdm = h.get("mdm") or {}
for k, v in (
    ("id", h.get("id")), ("hostname", h.get("hostname")), ("platform", h.get("platform")),
    ("os_version", h.get("os_version")), ("orbit_version", h.get("orbit_version")),
    ("osquery_version", h.get("osquery_version")),
    ("fleet", h.get("fleet_name") or h.get("team_name") or "Unassigned"),
    ("mdm_enrollment", mdm.get("enrollment_status")), ("status", h.get("status")),
    ("last_seen", h.get("seen_time")), ("disk_encryption", h.get("disk_encryption_enabled"))):
    print("%-16s %s" % (k, v))
'
}

case "${1:?see the header of this script}" in
  version)  get /api/v1/fleet/version | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["version"])' ;;
  host)     host_json "${2:?usage: fleet-api.sh host <serial|uuid|hostname>}" | show_host ;;
  wait-host)
    id="${2:?usage: fleet-api.sh wait-host <id> [seconds]}"; end=$(( $(date +%s) + ${3:-900} ))
    while [ "$(date +%s)" -lt "$end" ]; do
      # 404 means not enrolled yet. Any other failure is a setup problem, so stop and show it.
      if out=$(host_json "$id" 2>&1); then printf '%s' "$out" | show_host; exit 0; fi
      case "$out" in *"not found"*|*"404"*) sleep 5 ;; *) echo "$out" >&2; exit 1 ;; esac
    done
    echo "host $id did not appear" >&2; exit 1 ;;
  activity)
    get "/api/v1/fleet/hosts/${2:?usage: fleet-api.sh activity <host id>}/activities?per_page=100" | python3 -I -c '
import json, sys
for a in (json.load(sys.stdin).get("activities") or []):
    print(a.get("created_at"), a.get("type"), json.dumps(a.get("details") or {}, sort_keys=True))' ;;
  *) echo "unknown command" >&2; exit 2 ;;
esac
