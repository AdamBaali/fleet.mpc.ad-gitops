#!/bin/bash
# fleetdm/fleet#46924 PN-3: shows whether a script keeps running while the Mac sleeps.
# Gaps longer than 10 seconds in the log mean the Mac slept mid-script.
log=/var/tmp/fleet-pn-script.log
echo "start $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log"
for i in $(seq 1 12); do
  sleep 10
  echo "tick $i $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log"
done
echo "end $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log"
rm -f /var/tmp/fleet-pn-script
cat "$log"
