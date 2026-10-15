#!/bin/bash
# usage: s.sh <vm> <evidence-dir> <label> [clickd X Y | type TEXT]   -> acts, waits 4s, screenshots as NN-label.png
VM=$1; D=$2; L=$3; shift 3
H="$(cd "$(dirname "$0")" && pwd)"
case "$1" in clickd) "$H/utm-vm.sh" "$VM" clickd "$2" "$3";; type) "$H/utm-vm.sh" "$VM" type "$2";; esac
t=$(( $(date +%s)+${WAIT:-4} )); until [ $(date +%s) -ge $t ]; do sleep 1; done
n=$(printf '%02d' $(( $(ls "$D" | wc -l)+1 )))
"$H/utm-vm.sh" "$VM" shot "$D/$n-$L.png" >/dev/null && echo "$D/$n-$L.png"
