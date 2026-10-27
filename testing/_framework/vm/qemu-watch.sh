#!/bin/bash
# Watch a VM started by qemu-boot.sh and keep each new screen as evidence.
# Usage: qemu-watch.sh <evidence dir> <name> <minutes> [stop regex]
# Every 20 s: screendump, kept only when it differs from the last kept one, plus a log line with
# the guest agent's answer (hostname, or "none" while Windows is down) and QEMU's CPU use.
# Stops early when the guest agent's hostname matches the stop regex, or, for "!<name>", when it
# answers with any hostname other than <name> (a reset gives Windows a new one).
set -uo pipefail
out=$1 name=$2 mins=$3 stop=${4:-}
tools=$(cd "$(dirname "$0")" && pwd)
pid=$(cat "${VM_ROOT:-$PWD/out/qemu}/$name/pid")
mkdir -p "$out"; log=$out/watch.log; last=""; n=$(ls "$out"/*.png 2>/dev/null | wc -l | tr -d ' ')
end=$(( $(date +%s) + mins * 60 ))
while [ "$(date +%s)" -lt "$end" ]; do
  kill -0 "$pid" 2>/dev/null || { echo "$(date -u +%FT%TZ) qemu exited" >> "$log"; exit 1; }
  tmp=$out/.cur.png
  "$tools/qmp.sh" "$name" shot "$tmp" >/dev/null 2>&1
  sum=$(md5 -q "$tmp" 2>/dev/null)
  if [ -n "$sum" ] && [ "$sum" != "$last" ]; then
    n=$((n + 1)); cp "$tmp" "$out/$(printf %03d $n)-$(date -u +%H%M%S).png"; last=$sum
  fi
  host=$("$tools/qga.sh" "$name" 'hostname' 8 2>/dev/null | tr -d '\r\n')
  echo "$(date -u +%FT%TZ) qga=${host:-none} cpu=$(ps -o %cpu= -p "$pid" | tr -d ' ') frame=$n" >> "$log"
  if [ -n "$stop" ] && [ -n "${host:-}" ] && { [[ $stop == !* && $host != "${stop#!}" ]] || [[ $stop != !* && $host =~ $stop ]]; }; then echo "stop matched: $host" >> "$log"; exit 0; fi
  sleep 20
done
rm -f "$out/.cur.png"
