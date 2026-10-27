#!/bin/bash
# Works around UTM/QEMU's warm-reboot hang on Apple Silicon (utmapp/UTM#7648): after a guest-initiated restart the
# firmware sometimes spins before boot device selection, showing "Start boot option" with one vCPU pegged. A forced
# power-off and cold start always recovers, and Windows resets and generalize reboot several times, so each hang needs
# a cycle. Signature: the VM window unchanged for 90 s while its QEMU process is above 90% CPU (an idle setup screen
# is unchanged but near 0% CPU). Each cycle is logged and the hung frame kept as evidence.
# Usage: tools/hang-watchdog.sh <test-id> <vm> [timeout minutes, default 180]
set -u
ID="$1"; V="$2"; T="${3:-180}"
U=/Applications/UTM.app/Contents/MacOS/utmctl
D=$(ls -d test-evidence/*/"$ID"-* | head -1); LOG="$D/watchdog.txt"
UUID=$(/usr/libexec/PlistBuddy -c 'Print :Information:UUID' "$HOME/Library/Containers/com.utmapp.UTM/Data/Documents/$V.utm/config.plist")
# utmctl start sometimes fails right after a kill (OSStatus -2700); retry until UTM reports the VM started.
start_vm() { for t in 1 2 3 4 5 6; do $U start "$V" >/dev/null 2>&1; sleep 5; $U status "$V" 2>/dev/null | grep -q started && return 0; sleep 5; done; echo "$(date -u +%FT%TZ) could not start $V" >> "$LOG"; }
TMP=$(mktemp -d); last=""; same=0; end=$(( $(date +%s) + T*60 ))
echo "$(date -u +%FT%TZ) start vm=$V uuid=$UUID" >> "$LOG"
while [ "$(date +%s)" -lt "$end" ] && [ ! -e "$D/.stop-watchdog" ]; do
  # A stopped VM is unexpected during a test unless the test allows it (.allow-stop in the evidence folder).
  if $U status "$V" 2>/dev/null | grep -q stopped && [ ! -e "$D/.allow-stop" ]; then
    echo "$(date -u +%FT%TZ) $V found stopped, starting" >> "$LOG"; start_vm
  fi
  if $U status "$V" 2>/dev/null | grep -q started; then
    W=$("$HOME/.local/bin/winid-all" UTM "$V" 2>/dev/null) && screencapture -x -o -l"$W" "$TMP/f.png" 2>/dev/null
    h=$(md5 -q "$TMP/f.png" 2>/dev/null)
    cpu=$(ps -Ao pcpu,command | grep "qemu-aarch64" | grep "$UUID" | grep -v grep | awk '{print int($1)}' | head -1)
    if [ -n "$h" ] && [ "$h" = "$last" ]; then same=$((same+1)); else same=0; fi
    last="$h"
    if [ "$same" -ge 6 ] && [ "${cpu:-0}" -ge 90 ]; then
      n=$(printf '%03d' $(( $(ls "$D" | grep -cE '^[0-9]+-') + 1 ))); cp "$TMP/f.png" "$D/$n-hang-before-cycle.png"
      echo "- \`$n-hang-before-cycle.png\` (window screenshot: frame unchanged 90 s, QEMU ${cpu}% CPU)" >> "$D/result.md"
      echo "$(date -u +%FT%TZ) $V hang detected (frame unchanged 90 s, cpu ${cpu}%), power-cycling" >> "$LOG"
      $U stop "$V" --kill >/dev/null 2>&1; sleep 5; start_vm; same=0; last=""
    fi
  fi
  sleep 15
done
echo "$(date -u +%FT%TZ) stop" >> "$LOG"; rm -rf "$TMP"
