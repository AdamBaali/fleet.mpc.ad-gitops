#!/bin/bash
# Cold-boots a VM under the hang watchdog and reports whether Windows came up, judged by a DHCP lease for the VM's MAC
# (only a running Windows asks for one), or for a VM without a network driver, by an idle screen: frame unchanged
# and QEMU under 40% CPU for 2 minutes (a hang keeps a vCPU pegged). Usage: tools/boot-check.sh <test-id> <vm> [minutes, default 25]
set -u
ID="$1"; V="$2"; M="${3:-25}"; U=/Applications/UTM.app/Contents/MacOS/utmctl
D=$(ls -d test-evidence/*/"$ID"-* | head -1)
MAC=$(/usr/libexec/PlistBuddy -c 'Print :Network:0:MacAddress' "$HOME/Library/Containers/com.utmapp.UTM/Data/Documents/$V.utm/config.plist" | tr 'A-F' 'a-f' | sed -E 's/(^|:)0([0-9a-f])/\1\2/g')
start=$(date +%s); $U start "$V" >/dev/null 2>&1
tools/hang-watchdog.sh "$ID" "$V" "$M" & WD=$!
res="NO BOOT after $M min"; UUID=$(/usr/libexec/PlistBuddy -c 'Print :Information:UUID' "$HOME/Library/Containers/com.utmapp.UTM/Data/Documents/$V.utm/config.plist"); idle=0; last=""; T=$(mktemp)
while [ $(( $(date +%s) - start )) -lt $(( M*60 )) ]; do
  if [ "$(stat -f %m /var/db/dhcpd_leases)" -gt "$start" ] && grep -q "hw_address=1,$MAC" /var/db/dhcpd_leases; then res="BOOTED: DHCP lease for $MAC after $(( $(date +%s) - start )) s"; break; fi
  W=$("$HOME/.local/bin/winid-all" UTM "$V" 2>/dev/null) && screencapture -x -o -l"$W" "$T" 2>/dev/null; h=$(md5 -q "$T" 2>/dev/null)
  cpu=$(ps -Ao pcpu,command | grep qemu-aarch64 | grep "$UUID" | grep -v grep | awk '{print int($1)}' | head -1)
  if [ -n "$h" ] && [ "$h" = "$last" ] && [ "${cpu:-100}" -lt 40 ]; then idle=$((idle+1)); else idle=0; fi; last="$h"
  if [ "$idle" -ge 8 ] && [ $(( $(date +%s) - start )) -gt 240 ]; then res="BOOTED: idle screen, QEMU ${cpu}% CPU after $(( $(date +%s) - start )) s"; break; fi
  sleep 15
done
touch "$D/.stop-watchdog"; sleep 16; rm -f "$D/.stop-watchdog"; kill $WD 2>/dev/null
"$HOME/.local/bin/winid-all" UTM "$V" >/dev/null && PATH=$HOME/.local/bin:$PATH tools/shot.sh "$ID" "boot-check-end" UTM "$V" >/dev/null
echo "$(date -u +%FT%TZ) $V: $res" | tee -a "$D/watchdog.txt"
