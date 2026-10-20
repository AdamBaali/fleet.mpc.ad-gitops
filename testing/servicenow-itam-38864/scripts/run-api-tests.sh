#!/usr/bin/env bash
# API-only ITAM tests (fleetdm/fleet#38864): S-1 (API part), H-1 to H-6, A-1, A-2, A-3, U-1.
# Runs from any machine that reaches Fleet. Writes evidence with the framework's ev.sh.
#
# Usage: ./run-api-tests.sh <action> <fleet_id> [args]
#   setup <fleet_id>                     S-1: the seven ITAM reports exist, hosts per platform
#   hosts <fleet_id>                     H-1..H-6: every host field the issue lists, per host
#   report-cap <fleet_id>                A-2: rows and clipping per report, estimate for 2000 Macs
#   export <fleet_id>                    A-1: run fleet_itam_export.py, check field coverage, run compare.py
#   watch <fleet_id> <host_id> <name> present|absent [timeout_s]
#                                        A-3, U-1: minutes until a change shows in the software API.
#                                        The reports refresh hourly; U-2 checks them through the export
#   all <fleet_id>                       setup, hosts, report-cap, export
# Needs FLEET_URL and FLEET_API_TOKEN (or SECRETS_ENV), curl, jq and python3.
# ITAM_STATE overrides where the exporter keeps first seen dates (default ../test-evidence/first_seen.json).
set -euo pipefail
# SCRIPTS, not HERE: ev.sh sets HERE to its own folder.
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
export SCRIPTS
PROJECT="$(cd "$SCRIPTS/.." && pwd)"
export EV="${EV:-$PROJECT/test-evidence/api}"
mkdir -p "$EV"
. "$SCRIPTS/fleet-api.sh"
. "$PROJECT/../_framework/bin/ev.sh"
_itam_load_env
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export TMP

ITAM_REPORTS=(
  "ITAM macOS app install date" "ITAM macOS app publisher" "ITAM macOS package receipts"
  "ITAM Windows program install date and publisher" "ITAM Windows uninstall key written"
  "ITAM Linux RPM install date and vendor" "ITAM Linux DEB install date and maintainer"
)

hosts_file() { [ -s "$TMP/hosts.jsonl" ] || fleet_hosts "$1" > "$TMP/hosts.jsonl"; echo "$TMP/hosts.jsonl"; }

t_setup() {
  local f id missing=0; f="$(hosts_file "$1")"
  ev_init S-1 "API setup check" "The ITAM reports exist in the fleet and hosts of each OS are enrolled" "7 reports found, at least one host per OS" >/dev/null
  for n in "${ITAM_REPORTS[@]}"; do
    id="$(fleet_report_id "$n" "$1")"
    ev_note S-1 "- $n: ${id:-MISSING}"
    [ -n "$id" ] || missing=$((missing + 1))
  done
  ev_cmd S-1 hosts-per-platform "jq -r '.platform' '$f' | sort | uniq -c"
  local plats; plats="$(jq -r '.platform' "$f" | sed 's/ubuntu\|fedora\|rhel\|debian/linux/' | sort -u | tr '\n' ' ')"
  if [ "$missing" -eq 0 ] && [[ "$plats" == *darwin* && "$plats" == *windows* && "$plats" == *linux* ]]; then
    ev_verdict S-1 PASS "All reports found. Platforms: $plats"
  else
    ev_verdict S-1 FAIL "$missing report(s) missing. Platforms: $plats"
  fi
}

# One test per issue host field. PARTIAL names the hosts with an empty value, so a VM serial or a host
# without an IdP user reads as a known gap, not a failure.
field_test() { # id title jq-expr f
  local id="$1" title="$2" expr="$3" f="$4" empty total
  ev_init "$id" "$title" "Fleet returns $title for every host in the fleet" "Value on every host. Known gaps: VM serials, hosts without an IdP user" >/dev/null
  ev_cmd "$id" values "jq -r '[.platform, .hostname, ($expr | tostring)] | @tsv' '$f'"
  total="$(jq -s 'length' "$f")"
  empty="$(jq -r "select((($expr) // \"\" | tostring) == \"\" or ($expr) == null) | .hostname" "$f" | tr '\n' ' ')"
  if [ "$total" -eq 0 ]; then ev_verdict "$id" BLOCKED "No hosts in the fleet"
  elif [ -z "$empty" ]; then ev_verdict "$id" PASS "Present on all $total hosts"
  else ev_verdict "$id" PARTIAL "Empty on: $empty"; fi
}

t_hosts() {
  local f; f="$(hosts_file "$1")"
  field_test H-1 "host name" '(.display_name // .hostname)' "$f"
  field_test H-2 "OS and OS version" '(if (.os_version // "") == "" then "" else .platform + " / " + .os_version end)' "$f"
  field_test H-3 "serial number" '.hardware_serial' "$f"
  field_test H-4 "manufacturer and model" '(if (.hardware_vendor // "") == "" or (.hardware_model // "") == "" then "" else .hardware_vendor + " / " + .hardware_model end)' "$f"
  field_test H-5 "assigned user and department" '(((.end_users // [])[0] // {}) | if (.idp_username // "") == "" then "" else "user set / " + (.idp_department // "no department") end)' "$f"
  ev_note H-5 "IdP usernames are not written to evidence (personal data). The value shows only that one is set."
  field_test H-6 "last seen" '.seen_time' "$f"
  ev_note H-4 "Apple hosts report a model identifier (for example Mac15,9), not a marketing name. Map it in ServiceNow if needed."
}

t_report_cap() {
  local rid body count clipped mac_rows=0 macs clipped_any=0
  ev_init A-2 "report cap" "Each ITAM report fits under report_cap and is not clipped" "Lab under 10000 rows, report_clipped false" >/dev/null
  for n in "${ITAM_REPORTS[@]}"; do
    rid="$(fleet_report_id "$n" "$1")"; [ -n "$rid" ] || { ev_note A-2 "- $n: not found"; continue; }
    body="$(fleet_get "/api/v1/fleet/reports/$rid/report" "fleet_id=$1&per_page=1")"
    count="$(jq '.count' <<<"$body")"; clipped="$(jq '.report_clipped' <<<"$body")"
    ev_note A-2 "- $n (id $rid): count $count, clipped $clipped"
    [ "$clipped" = true ] && clipped_any=1
    [ "$n" = "ITAM macOS app install date" ] && mac_rows="$count"
  done
  macs="$(jq -s '[.[] | select(.platform == "darwin")] | length' "$(hosts_file "$1")")"
  [ "$macs" -gt 0 ] && ev_note A-2 "Estimate: $((mac_rows / macs)) rows per Mac, so 2000 Macs is about $((mac_rows / macs * 2000)) rows in one report."
  [ "$clipped_any" -eq 0 ] && ev_verdict A-2 PASS "No ITAM report clipped" || ev_verdict A-2 FAIL "At least one report clipped"
}

t_export() {
  local out="$EV/export-out"; mkdir -p "$out"
  ev_init A-1 "API pull and join" "The exporter pulls every host, its software and every ITAM report, and joins them" "One JSON per host, every field in the field map filled or labeled" >/dev/null
  ev_cmd A-1 exporter "python3 '$SCRIPTS/fleet_itam_export.py' --fleet-id $1 --out '$out' --state '${ITAM_STATE:-$PROJECT/test-evidence/first_seen.json}'"
  ev_cmd A-1 field-coverage "python3 - '$out' <<'PY'
import json, sys, glob, collections
c = collections.Counter(); t = collections.Counter()
for p in glob.glob(sys.argv[1] + '/hosts/*.json'):
    d = json.load(open(p)); plat = d['host']['platform']
    for r in d['software']:
        t[plat] += 1
        for k in ('publisher', 'install_date', 'first_seen', 'last_used', 'install_location'):
            if r[k]: c[(plat, k)] += 1
        c[(plat, 'src:' + r['install_date_source'].split(':')[0])] += 1
for plat in sorted(t):
    print(plat, 'rows', t[plat], ' '.join('%s=%d%%' % (k, 100 * c[(plat, k)] // t[plat]) for k in ('publisher', 'install_date', 'first_seen', 'last_used', 'install_location')))
    print('  install_date sources:', {k[1]: v for k, v in c.items() if k[0] == plat and k[1].startswith('src:')})
PY"
  if ls "$PROJECT"/ground-truth/*.tsv >/dev/null 2>&1; then
    ev_cmd A-1 compare "python3 '$SCRIPTS/compare.py' --gt $PROJECT/ground-truth/*.tsv --export '$out' --out '$EV/verdicts' && cat '$EV/verdicts/verdicts.md'"
  fi
  local n; n="$(ls "$out"/hosts/*.json 2>/dev/null | wc -l | tr -d ' ')"
  [ "$n" -gt 0 ] && ev_verdict A-1 PASS "$n host files written. Coverage per field in 02-field-coverage.txt" || ev_verdict A-1 FAIL "No host files written"
}

# Polls once a minute. A test tool waiting on Fleet's own refresh, so a short interval is fine.
t_watch() { # fleet_id host_id name present|absent timeout
  local id; case "$4" in present) id=A-3 ;; absent) id=U-1 ;; *) echo "present|absent" >&2; exit 2 ;; esac
  local start now sw_done=""; start="$(date +%s)"
  ev_init "$id" "$3 $4 in Fleet" "Minutes until $3 is $4 in the software API" "Within 60 minutes (hourly export)" >/dev/null
  while :; do
    now="$(date +%s)"
    local hit; hit="$(fleet_host_software "$2" | jq -r --arg n "$3" 'select(.name | ascii_downcase | startswith($n | ascii_downcase)) | .name' | head -1)"
    if { [ "$4" = present ] && [ -n "$hit" ]; } || { [ "$4" = absent ] && [ -z "$hit" ]; }; then
      sw_done=$(( (now - start) / 60 )); ev_note "$id" "- software API: $4 after $sw_done min"; break; fi
    [ $((now - start)) -ge "${5:-5400}" ] && break
    sleep 60
  done
  if [ -n "$sw_done" ] && [ "$sw_done" -le 60 ]; then
    ev_verdict "$id" PASS "Software API $sw_done min"
  else
    ev_verdict "$id" FAIL "Software API ${sw_done:-not seen} min"
  fi
}

act="${1:-}"; fid="${2:-}"
[ -n "$act" ] && [ -n "$fid" ] || { sed -n '2,15p' "$0"; exit 2; }
case "$act" in
  setup) t_setup "$fid" ;;
  hosts) t_hosts "$fid" ;;
  report-cap) t_report_cap "$fid" ;;
  export) t_export "$fid" ;;
  watch) t_watch "$fid" "${3:?host_id}" "${4:?name}" "${5:?present|absent}" "${6:-5400}" ;;
  all) t_setup "$fid"; t_hosts "$fid"; t_report_cap "$fid"; t_export "$fid" ;;
  *) sed -n '2,15p' "$0"; exit 2 ;;
esac
