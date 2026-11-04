#!/usr/bin/env bash
# Option 3 step: after an Android host finishes setup, move it to the fleet with the password profile,
# or add it to the manual label that the profile targets. Finds the host by hardware serial number.
#
# Usage:
#   move-host.sh SERIAL --fleet "android-pin-enforced" [--apply]
#   move-host.sh SERIAL --label "android-pin-ready" [--apply]
#   move-host.sh SERIAL --remove-label "android-pin-ready" [--apply]
#
# Without --apply it prints what it would do and changes nothing.
# Needs FLEET_URL and FLEET_API_TOKEN in the environment (keep them in private/fleet.env, which git ignores).
#
# REST API calls used (docs/API/rest-api.md in fleetdm/fleet):
#   GET  /api/v1/fleet/hosts/identifier/:serial   finds the host ID and current fleet
#   GET  /api/v1/fleet/fleets                     finds the fleet ID by name
#   POST /api/v1/fleet/hosts/transfer             moves the host (Fleet Premium)
#   POST /api/v1/fleet/hosts/:id/labels           adds manual labels
#   DELETE /api/v1/fleet/hosts/:id/labels         removes manual labels
# fleetctl's "hosts transfer" takes hostnames, not serials, which is why this uses the REST API.
set -euo pipefail

usage() { sed -n '4,7p' "$0" >&2; exit 2; }
[ $# -ge 3 ] || usage
serial="$1"; mode="$2"; target="$3"; apply="${4:-}"
case "$mode" in --fleet|--label|--remove-label) ;; *) usage ;; esac
[ -z "$apply" ] || [ "$apply" = "--apply" ] || usage
: "${FLEET_URL:?set FLEET_URL}" "${FLEET_API_TOKEN:?set FLEET_API_TOKEN}"

api() { # method, path, [json body]
  local args=(-sS --fail-with-body -X "$1" -H "Authorization: Bearer $FLEET_API_TOKEN" -H "Content-Type: application/json")
  [ $# -ge 3 ] && args+=(--data "$3")
  curl "${args[@]}" "${FLEET_URL%/}$2"
}
json() { python3 -I -c "import json,sys; d=json.load(sys.stdin); $1" "${@:2}"; }
ts() { date -u +%FT%TZ; }

host_json=$(api GET "/api/v1/fleet/hosts/identifier/$(python3 -I -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1], safe=""))' "$serial")?exclude_software=true") \
  || { echo "no host with serial \"$serial\" (or the API call failed)" >&2; exit 1; }
host_id=$(echo "$host_json" | json 'print(d["host"]["id"])')
# Fleet 4.9x returns both names during the team -> fleet rename. Read whichever is present.
from_fleet=$(echo "$host_json" | json 'h=d["host"]; print(h.get("fleet_name") or h.get("team_name") or "Unassigned")')
platform=$(echo "$host_json" | json 'print(d["host"].get("platform",""))')
echo "$(ts) host id=$host_id serial=$serial platform=$platform fleet=\"$from_fleet\""
[ "$platform" = "android" ] || echo "warning: platform is \"$platform\", not android" >&2

case "$mode" in
  --fleet)
    fleet_id=$(api GET "/api/v1/fleet/fleets?query=$(python3 -I -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1], safe=""))' "$target")" \
      | json 'import sys; m=[f["id"] for f in d.get("fleets", d.get("teams", [])) if f["name"]==sys.argv[1]]; print(m[0] if m else "")' "$target")
    [ -n "$fleet_id" ] || { echo "no fleet named \"$target\"" >&2; exit 1; }
    # Send both keys: older servers read team_id, newer ones fleet_id.
    body="{\"fleet_id\": $fleet_id, \"team_id\": $fleet_id, \"hosts\": [$host_id]}"
    echo "$(ts) transfer host $host_id: \"$from_fleet\" -> \"$target\" (fleet id $fleet_id)"
    [ "$apply" = "--apply" ] || { echo "dry run: POST /api/v1/fleet/hosts/transfer $body"; exit 0; }
    api POST /api/v1/fleet/hosts/transfer "$body" >/dev/null
    ;;
  --label|--remove-label)
    method=POST; [ "$mode" = "--remove-label" ] && method=DELETE
    body=$(python3 -I -c 'import json,sys;print(json.dumps({"labels":[sys.argv[1]]}))' "$target")
    echo "$(ts) $method label \"$target\" on host $host_id"
    [ "$apply" = "--apply" ] || { echo "dry run: $method /api/v1/fleet/hosts/$host_id/labels $body"; exit 0; }
    api "$method" "/api/v1/fleet/hosts/$host_id/labels" "$body" >/dev/null
    ;;
esac
echo "$(ts) done. Fleet's Android profile job runs every 30 seconds and then patches the host's Google policy."
