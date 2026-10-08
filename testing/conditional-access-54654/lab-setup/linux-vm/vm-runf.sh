#!/usr/bin/env bash
# Run a local script file in the lab-linux VM as root via the UTM guest agent; print its output.
# Usage: vm-runf.sh script.sh [timeout-seconds]
U=/Applications/UTM.app/Contents/MacOS/utmctl; T="${2:-60}"; N="/tmp/vmrunf-$$"
{ echo '#!/bin/bash'; echo "( bash $N.body ) > $N.out 2>&1; echo \"[exit \$?]\" >> $N.out"; } > "/tmp/wrap-$$.sh"
$U file push lab-linux $N.body < "$1" >/dev/null 2>&1
$U file push lab-linux $N.sh < "/tmp/wrap-$$.sh" >/dev/null 2>&1; rm -f "/tmp/wrap-$$.sh"
$U exec lab-linux --cmd /bin/bash $N.sh >/dev/null 2>&1
for i in $(seq 1 $((T/2))); do out=$($U file pull lab-linux $N.out 2>/dev/null); echo "$out" | grep -q '^\[exit ' && break; sleep 2; done
echo "$out"
