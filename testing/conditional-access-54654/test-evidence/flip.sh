#!/bin/bash
# usage: flip.sh fail|pass   -- make the critical policy fail (create flag file) or pass (remove it), Refetch, and time Fleet's view.
. "$(dirname "$0")/lib.sh"
want=$([ "$1" = fail ] && echo 1 || echo 0)
UUID=86d7dc8e-3373-47af-86dd-56a1cd517e2f
count() { HID=$(fleetctl api "/hosts/identifier/$UUID" 2>/dev/null | jq -r .host.id); curl -s -H "Authorization: Bearer $FLEET_TOKEN_PING" "$FLEET_URL/api/v1/fleet/hosts/$HID/health" | jq -r '.health.failing_critical_policies_count'; }
t0=$(date +%s)
echo "$(date -u +%T) T+0s   action: $([ "$1" = fail ] && echo 'create /tmp/fleet-ca-test in the VM' || echo 'remove /tmp/fleet-ca-test in the VM')"
bash "$LAB/vm/linux/vm-run.sh" "$([ "$1" = fail ] && echo 'touch /tmp/fleet-ca-test' || echo 'unlink /tmp/fleet-ca-test'); ls -la /tmp/fleet-ca-test 2>&1 | cut -c1-80" | head -2
echo "failing_critical_policies_count before Refetch: $(count)"
HID=$(fleetctl api "/hosts/identifier/$UUID" 2>/dev/null | jq -r .host.id)
fleetctl api -X POST "/hosts/$HID/refetch" >/dev/null 2>&1; echo "$(date -u +%T) T+$(( $(date +%s)-t0 ))s  Refetch requested (same as 'Refetch' on the My device page)"
while :; do
  sleep 5; c=$(count); el=$(( $(date +%s)-t0 ))
  echo "$(date -u +%T) T+${el}s   failing_critical_policies_count=$c"
  [ "$c" = "$want" ] && { echo "RESULT: Fleet saw the change $el seconds after the change was made (target count $want)"; break; }
  [ $el -gt 300 ] && { echo "RESULT: no change after 300 s"; break; }
done
