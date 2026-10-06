#!/usr/bin/env bash
# D-8 for Linux: with REQUIRE_PASSING_CRITICAL_POLICIES=true, does a host that fails a critical policy leave
# the Duo cache, and what happens when it is the only host? Needs the lab-linux VM running (host id in $HID).
set -uo pipefail
LAB="$(cd "$(dirname "$0")/.." && pwd)"; set -a; . "$LAB/.env"; set +a; cd "$LAB/duo/run"
U=/Applications/UTM.app/Contents/MacOS/utmctl; PY="$LAB/.venv/bin/python"; SYNC="$LAB/secrets/duo/linux/device_cache_sync.py"; HID="${HID:-6}"
exp()  { FLEET_API_TOKEN="$FLEET_TOKEN_DUO" REQUIRE_PASSING_CRITICAL_POLICIES=true ./export.sh >/dev/null 2>&1; echo "linux.csv rows=$(($(wc -l < linux.csv)-1))"; }
sync() { "$PY" "$SYNC" --infile linux.csv 2>&1 | grep -E "devices uploaded|Activated|Devices synced|No device IDs|Deleted" | sed 's/cache_key: *[A-Z0-9]*//'; echo "sync exit=${PIPESTATUS[0]}"; }
crit() { curl -s -H "Authorization: Bearer $FLEET_TOKEN_PING" "$FLEET_URL/api/v1/fleet/hosts/$HID/health" | jq -r '.health.failing_critical_policies_count'; }
waitc(){ T0=$(date +%s); for i in $(seq 1 40); do sleep 4; [ "$(crit)" = "$1" ] && { echo "Fleet shows failing_critical=$1 after $(( $(date +%s)-T0 ))s"; return 0; }; done; echo "timeout"; return 1; }
echo "== 1. baseline, host passing"; exp; sync
echo "== 2. fail the critical policy, refetch"; $U exec lab-linux --cmd /usr/bin/touch /tmp/fleet-ca-test; fleetctl api -X POST /hosts/$HID/refetch >/dev/null 2>&1; waitc 1
echo "== 3. export + sync while failing (the host is the only Linux host)"; exp; sync
echo "== 4. fix, refetch"; $U exec lab-linux --cmd /usr/bin/unlink /tmp/fleet-ca-test; fleetctl api -X POST /hosts/$HID/refetch >/dev/null 2>&1; waitc 0
echo "== 5. export + sync after the fix"; exp; sync
