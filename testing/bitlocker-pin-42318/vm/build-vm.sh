#!/bin/bash
# Builds the #42318 VM "bitlocker-lab" end to end: create in UTM, add TPM 2.0 and the two ISOs (cloned into the bundle so
# UTM's sandbox can read them, no UI step), start, and press a key so it boots the Windows ISO. Unattended from there.
set -euo pipefail
LAB="$(cd "$(dirname "$0")/.." && pwd)"
ISO=/Users/adam/Downloads/fleet-54654-lab/vm/windows/Windows11_Client_arm64_en-us_26300_9457.iso
DOCS=~/Library/Containers/com.utmapp.UTM/Data/Documents; B="$DOCS/bitlocker-lab.utm"; U=/Applications/UTM.app/Contents/MacOS/utmctl
[ -e "$B" ] && { echo "$B exists; move it away first"; exit 1; }
open -g -a UTM; sleep 4
osascript "$LAB/vm/create-vm.applescript"
osascript -e 'tell application "UTM" to quit'; for i in $(seq 1 20); do pgrep -x UTM >/dev/null || break; sleep 1; done
cp -c "$ISO" "$B/Data/win11-arm64-26300.iso"; cp -c "$LAB/vm/answer.iso" "$B/Data/answer.iso"
/usr/libexec/PlistBuddy -c "Set :QEMU:TPMDevice true" -c "Add :Drive:1:ImageName string win11-arm64-26300.iso" \
  -c "Add :Drive:2:ImageName string answer.iso" "$B/config.plist"
open -g -a UTM; sleep 4
$U start bitlocker-lab
for i in $(seq 1 14); do osascript -e 'tell application "UTM" to input keystroke (get virtual machine named "bitlocker-lab") text " "'; sleep 1; done
$U status bitlocker-lab
