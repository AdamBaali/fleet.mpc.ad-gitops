#!/usr/bin/env bash
# Evidence for the Power Nap tests (fleetdm/fleet#46924). Run on the MacBook Air from the repo root.
#
#   testing/power-nap-46924/scripts/collect.sh baseline
#       B-1: power settings, model, macOS and fleetd versions.
#   testing/power-nap-46924/scripts/collect.sh window <ID> "<since>"
#       Logs for one run (C-1, PN-1 to PN-7), from <since> ("YYYY-MM-DD HH:MM", local time) to now.
#
# The finding is the line-up of orbit errors with DarkWake and Sleep times, so both logs are cut
# to the same window. orbit.stderr.log is root-only, so the window mode asks for sudo.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
export EV="${EV:-$HERE/../test-evidence/mac}"
mkdir -p "$EV"
. "$HERE/../../_framework/bin/ev.sh"

case "${1:-}" in
  baseline)
    ev_init B-1 "Baseline power settings" "Record the Mac's power settings before any run" "Power Nap, tcpkeepalive and standby values saved" >/dev/null
    ev_cmd B-1 model "sysctl hw.model; sw_vers"
    ev_cmd B-1 pmset-custom "pmset -g custom"
    ev_cmd B-1 pmset-current "pmset -g"
    ev_cmd B-1 power-source "pmset -g batt"
    ev_cmd B-1 fleetd-versions "/opt/orbit/bin/orbit/orbit --version 2>&1 | head -3; find /opt/orbit/bin/osqueryd -name osqueryd -type f -exec {} --version \\;"
    ev_verdict B-1 INFO "Values recorded. Restore any pmset change to these at teardown"
    ;;
  window)
    id="${2:?test ID, for example PN-1}"; since="${3:?since, for example \"2026-10-21 22:00\"}"
    # orbit writes local time as 2026-10-21T22:00:05, pmset as 2026-10-21 22:00:05, so one cut fits both.
    cut_t="${since/ /T}"
    [ -n "$(ls -d "$EV/$id"-* 2>/dev/null)" ] || ev_init "$id" "Run logs" "Logs for $id from $since" "orbit and pmset logs for the same window" >/dev/null
    ev_cmd "$id" pmset-sleep-wake "pmset -g log | awk -v s='$since' 'substr(\$0,1,16) >= s' | grep -E ' (Sleep|Wake|DarkWake) '"
    ev_cmd "$id" pmset-assertions "pmset -g assertions"
    ev_cmd "$id" power-source "pmset -g batt"
    ev_cmd "$id" orbit-log "sudo awk -v s='$cut_t' 'substr(\$0,1,16) >= s' /var/log/orbit/orbit.stderr.log | grep -i -E 'install|download|script|error|fail' | tail -400"
    ev_cmd "$id" script-log "cat /var/tmp/fleet-pn-script.log 2>/dev/null || echo 'no script log'"
    ev_note "$id" "Add the Fleet activities for the same window, then set the verdict with ev_verdict."
    echo "Saved under $(ls -d "$EV/$id"-*)"
    ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac
