#!/bin/bash
# T-3: pull both stored reports through the API, fleet-wide and per host, and compare with the
# IDs fake-ids.ps1 wrote. Uses the calls from the API walkthrough sent to the customer.
# Usage: scripts/run-t3.sh <vm> <host id> <intune report id> <entra report id>
set -uo pipefail
vm=$1 host=$2 rin=$3 ren=$4
cd "$(dirname "$0")/.."
export EV=$PWD/test-evidence/lab
. ../_framework/bin/ev.sh
api() { echo "scripts/fleet-api.sh '$1' | python3 -m json.tool"; }

ev_init T-3 "Stored report and API" "Both reports store one row per host and return it through the report and host endpoints" \
  "Rows match the faked IDs; report_clipped is false" > /dev/null
ev_cmd T-3 expected "tools/qga.sh $vm 'Get-Content C:\\ids\\expected.json'"
ev_cmd T-3 host "scripts/fleet-api.sh '/api/v1/fleet/hosts/$host' | python3 -c 'import sys,json; h=json.load(sys.stdin)[\"host\"]; print({k: h.get(k) for k in (\"id\",\"hostname\",\"platform\",\"os_version\",\"osquery_version\",\"fleet_name\",\"team_name\",\"status\")})'"
ev_cmd T-3 intune-all-paged "$(api "/api/v1/fleet/reports/$rin/report?page=0&per_page=500")"
ev_cmd T-3 entra-all-paged "$(api "/api/v1/fleet/reports/$ren/report?page=0&per_page=500")"
ev_cmd T-3 intune-all-export "$(api "/api/v1/fleet/reports/$rin/report")"
ev_cmd T-3 intune-host "$(api "/api/v1/fleet/hosts/$host/reports/$rin")"
ev_cmd T-3 entra-host "$(api "/api/v1/fleet/hosts/$host/reports/$ren")"
ev_cmd T-3 compare "python3 scripts/compare-t3.py $vm $host $rin $ren"
