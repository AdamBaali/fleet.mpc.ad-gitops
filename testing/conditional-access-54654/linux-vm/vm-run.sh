#!/usr/bin/env bash
# Run a command in the lab-linux VM as root through the UTM guest agent and print its output.
# Usage: vm-run.sh 'command string'
U=/Applications/UTM.app/Contents/MacOS/utmctl; T="$(mktemp)"
printf '#!/bin/bash\n( %s ) > /tmp/vmrun.out 2>&1; echo "[exit $?]" >> /tmp/vmrun.out\n' "$1" > "$T"
$U file push lab-linux /tmp/vmrun.sh < "$T" >/dev/null 2>&1; rm -f "$T"
$U exec lab-linux --cmd /bin/bash /tmp/vmrun.sh >/dev/null 2>&1
for i in $(seq 1 20); do out=$($U file pull lab-linux /tmp/vmrun.out 2>/dev/null); echo "$out" | grep -q '^\[exit ' && break; sleep 2; done
echo "$out"
