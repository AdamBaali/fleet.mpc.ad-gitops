#!/bin/bash
# Attaches a disk image as the VM's third USB drive, as a writable disk (like a USB flash drive), before the VM is
# opened in UTM. For a VM already listed in UTM, quit UTM first (the plist edit needs it closed).
# Usage: vm/attach-usb.sh <vm> <image>   e.g. vm/attach-usb.sh e1-bypass out/usb-pkg-b.img
set -euo pipefail
VM="$1"; IMG="$2"
B=~/Library/Containers/com.utmapp.UTM/Data/Documents/$VM.utm
[ -d "$B" ] && [ -f "$IMG" ] || { echo "need $B and $IMG"; exit 1; }
N=$(basename "$IMG"); cp -c "$IMG" "$B/Data/$N"
/usr/libexec/PlistBuddy -c "Set :Drive:3:ImageType Disk" -c "Set :Drive:3:ReadOnly false" \
  -c "Delete :Drive:3:ImageName" -c "Add :Drive:3:ImageName string $N" "$B/config.plist"
/usr/libexec/PlistBuddy -c 'Print :Drive:3' "$B/config.plist"
