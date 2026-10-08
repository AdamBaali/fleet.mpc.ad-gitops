#!/bin/bash
# usage: macflip.sh fail|pass -- create/remove /tmp/fleet-ca-test on this Mac, refetch host 12, wait until Fleet's failing_critical_policies_count matches
cd <lab>; set -a; . .env; set +a
want=$([ "$1" = fail ] && echo 1 || echo 0)
count() { curl -s -H "Authorization: Bearer $FLEET_TOKEN_PING" "$FLEET_URL/api/v1/fleet/hosts/12/health" | jq -r '.health.failing_critical_policies_count'; }
t0=$(date +%s); [ "$1" = fail ] && touch /tmp/fleet-ca-test || rm -f /tmp/fleet-ca-test
echo "$(date -u +%T) T+0s  $([ "$1" = fail ] && echo 'created' || echo 'removed') /tmp/fleet-ca-test on the Mac; count now $(count)"
fleetctl api -X POST /hosts/12/refetch >/dev/null 2>&1; echo "$(date -u +%T) refetch requested"
while :; do sleep 5; c=$(count); el=$(( $(date +%s)-t0 )); echo "$(date -u +%T) T+${el}s failing_critical_policies_count=$c"
  [ "$c" = "$want" ] && { echo "RESULT: Fleet saw the change after ${el}s"; break; }; [ $el -gt 400 ] && { echo "RESULT: no change after 400s"; break; }; done
