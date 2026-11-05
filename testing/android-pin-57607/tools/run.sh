#!/usr/bin/env bash
# One test run with the framework helpers (testing/_framework/bin/ev.sh), so every run leaves the same evidence.
# The device steps (factory reset, QR scan, setup wizard) are manual; this records the Fleet side and your notes.
#
#   run.sh start   ID "title" "objective" "expected"   creates test-evidence/<group>/<ID>-<slug>/result.md
#   run.sh watch   ID SERIAL [seconds]                 timeline of fleet, labels and profile status (run in its own terminal)
#   run.sh host    ID SERIAL                           one snapshot of the host from Fleet's API (secrets masked)
#   run.sh move    ID SERIAL --fleet NAME | --label NAME | --remove-label NAME
#   run.sh activity ID SERIAL                          Fleet activity log for the host since the run started
#   run.sh logs    ID                                  Fleet server logs from Render since the run started (Android lines only)
#   run.sh note    ID "text"                           adds a line to result.md (use it for each RESULTS.md field)
#   run.sh verdict ID PASS|FAIL|PARTIAL|NOT-RUN|BLOCKED|INFO "one-line reason"
#
# The group is the ID prefix before the dash (O2-3 -> test-evidence/O2/). Secrets come from private/fleet.env:
#   FLEET_URL=https://fleet.mpc.ad
#   FLEET_API_TOKEN=...          (masked in every saved output by the framework's redact.py)
set -euo pipefail
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SECRETS_ENV="$P/private/fleet.env"
[ -f "$SECRETS_ENV" ] || { echo "create $SECRETS_ENV first (see the header of this script)" >&2; exit 1; }
set -a; . "$SECRETS_ENV"; set +a

cmd="${1:?see the header of this script}"; id="${2:?test ID, for example O2-1}"; shift 2
export EV="$P/test-evidence/${id%%-*}"; mkdir -p "$EV"
. "$P/../_framework/bin/ev.sh"
cd "$P"; T=tools   # relative, so the saved command lines show no local paths
since() { sed -n "s/^- \*\*Started:\*\* //p" "$(ls -d "$EV/$id"-* | head -1)/result.md"; }

case "$cmd" in
  start)   ev_init "$id" "$1" "$2" "$3" >/dev/null
           ev_note "$id" "- **Fleet:** $FLEET_URL ($(curl -sS -H "Authorization: Bearer $FLEET_API_TOKEN" "$FLEET_URL/api/v1/fleet/version" | python3 -I -c 'import json,sys;print(json.load(sys.stdin).get("version","?"))' 2>/dev/null || echo "version unknown"))"
           ls -d "$EV/$id"-* ;;
  watch)   ev_cmd "$id" watch "'$T/watch-host.sh' '$1' '${2:-1800}' 5" ;;
  # Only the fields the plan records. The full host record has IP addresses and other details this public repo doesn't need.
  host)    ev_cmd "$id" host "curl -sS -H 'Authorization: Bearer \$FLEET_API_TOKEN' \"\$FLEET_URL/api/v1/fleet/hosts/identifier/$1?exclude_software=true\" | python3 -I '$T/host-fields.py'" ;;
  move)    ev_cmd "$id" move "'$T/move-host.sh' '$1' '$2' '$3' --apply" ;;
  # Both read the run's start time from result.md, so they cover exactly the run's window.
  activity) ev_cmd "$id" activity "'$T/fleet-activity.sh' '$1' '$(since)'" ;;
  logs)    ev_cmd "$id" server-logs "'$T/server-logs.sh' '$(since)'" ;;
  note)    ev_note "$id" "$1" ;;
  verdict) ev_verdict "$id" "$1" "$2" ;;
  *)       echo "unknown command $cmd" >&2; exit 2 ;;
esac
