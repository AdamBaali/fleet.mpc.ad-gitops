#!/bin/bash
# Detaches both ISOs from the stopped VM "bitlocker-lab" (BitLocker refuses a TPM protector while bootable media is present),
# then starts it and waits for the guest agent. The empty USB CD drives stay; only their images are removed.
set -euo pipefail
B=~/Library/Containers/com.utmapp.UTM/Data/Documents/bitlocker-lab.utm; U=/Applications/UTM.app/Contents/MacOS/utmctl
[ "$($U status bitlocker-lab 2>&1)" = "stopped" ] || { echo "VM is not stopped"; exit 1; }
osascript -e 'tell application "UTM" to quit'; for i in $(seq 1 20); do pgrep -x UTM >/dev/null || break; sleep 1; done
for i in 1 2; do /usr/libexec/PlistBuddy -c "Delete :Drive:$i:ImageName" "$B/config.plist" 2>/dev/null || true; done
plutil -convert json -o - "$B/config.plist" | python3 -c 'import json,sys; print([(d["ImageType"], d.get("ImageName")) for d in json.load(sys.stdin)["Drive"]])'
open -g -a UTM; sleep 4; $U start bitlocker-lab
end=$(( $(date +%s) + 600 ))
until $U ip-address bitlocker-lab 2>&1 | grep -q '^192\.168\.'; do [ $(date +%s) -gt $end ] && { echo "guest agent not up after 10 min"; exit 1; }; sleep 10; done
echo "guest agent up $(date +%H:%M:%S)"
