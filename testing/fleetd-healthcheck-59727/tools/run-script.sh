#!/usr/bin/env bash
# Run a saved Fleet script on one host and print its exit code and output.
# Usage: tools/run-script.sh <host id> <script name> [fleet id] [wait seconds]
#   tools/run-script.sh 37 fleetd-healthcheck.ps1 15
# Needs FLEET_URL and FLEET_API_TOKEN, from the environment or from FLEET_ENV (default ./private/fleet.env).
# The token's user must be allowed to run scripts on the fleet (maintainer or admin).
# Fleet keeps only the end of a long output, so the first sections of a big script can be cut off.
set -euo pipefail
env_file="${FLEET_ENV:-$PWD/private/fleet.env}"
[ -f "$env_file" ] && { set -a; . "$env_file"; set +a; }
: "${FLEET_URL:?set FLEET_URL (private/fleet.env)}" "${FLEET_API_TOKEN:?set FLEET_API_TOKEN (private/fleet.env)}"
host="${1:?usage: run-script.sh <host id> <script name> [fleet id] [wait seconds]}"
name="${2:?usage: run-script.sh <host id> <script name> [fleet id] [wait seconds]}"
fleet="${3:-15}"; wait_s="${4:-600}"
api() { curl -sS --fail-with-body -H "Authorization: Bearer $FLEET_API_TOKEN" -H 'Content-Type: application/json' "$@"; }

script_id=$(api "${FLEET_URL%/}/api/v1/fleet/scripts?team_id=${fleet}&per_page=200" \
  | python3 -I -c 'import json,sys; n=sys.argv[1]; print(next((s["id"] for s in json.load(sys.stdin).get("scripts") or [] if s["name"]==n), ""))' "$name")
[ -n "$script_id" ] || { echo "no script named $name in fleet $fleet (has GitOps applied?)" >&2; exit 1; }

exec_id=$(api -X POST "${FLEET_URL%/}/api/v1/fleet/scripts/run" -d "{\"host_id\": ${host}, \"script_id\": ${script_id}}" \
  | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["execution_id"])')
echo "script_id=${script_id} execution_id=${exec_id} queued $(date -u +%FT%TZ)"

end=$(( $(date +%s) + wait_s ))
while [ "$(date +%s)" -lt "$end" ]; do
  res=$(api "${FLEET_URL%/}/api/v1/fleet/scripts/results/${exec_id}")
  # exit_code stays null until the host reports a result.
  if printf '%s' "$res" | python3 -I -c 'import json,sys; sys.exit(0 if json.load(sys.stdin).get("exit_code") is not None else 1)'; then
    printf '%s' "$res" | python3 -I -c '
import json, sys
r = json.load(sys.stdin)
print("exit_code=%s runtime=%ss host_timeout=%s" % (r.get("exit_code"), r.get("runtime"), r.get("host_timeout")))
print(r.get("output") or "")'
    exit 0
  fi
  sleep 10
done
echo "no result after ${wait_s}s; check Fleet > Hosts > ${host} > Activity" >&2; exit 1
