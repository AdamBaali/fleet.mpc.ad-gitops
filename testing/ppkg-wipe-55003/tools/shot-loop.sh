#!/bin/bash
# Window screenshots of a VM every N seconds into a test's evidence folder, until the stop file exists or the timeout.
# Many pictures on purpose: trim later. Usage: tools/shot-loop.sh <test-id> <vm> [seconds=30] [timeout minutes=90]
set -u
ID="$1"; V="$2"; S="${3:-30}"; T="${4:-90}"
export PATH=$HOME/.local/bin:$PATH
D=$(ls -d test-evidence/*/"$ID"-* | head -1); end=$(( $(date +%s) + T*60 ))
while [ "$(date +%s)" -lt "$end" ] && [ ! -e "$D/.stop-shots" ]; do
  tools/shot.sh "$ID" "s$(date -u +%H%M%S)" UTM "$V" >/dev/null 2>&1; sleep "$S"
done
