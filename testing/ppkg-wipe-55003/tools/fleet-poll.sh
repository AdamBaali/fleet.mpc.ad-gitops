#!/bin/bash
# Logs a Fleet host's enrollment state every 30 s, one line per change, while a VM resets.
# Usage: tools/fleet-poll.sh <host id> <out file> <minutes>
set -uo pipefail
id=$1 out=$2 mins=$3 last=""
end=$(( $(date +%s) + mins * 60 ))
while [ "$(date +%s)" -lt "$end" ]; do
  line=$(fleetctl api "/api/v1/fleet/hosts/$id" 2>/dev/null | python3 -I "$(dirname "$0")/fleet-host-line.py")
  [ "$line" != "$last" ] && echo "$(date -u +%FT%TZ) $line" >> "$out" && last=$line
  sleep 30
done
