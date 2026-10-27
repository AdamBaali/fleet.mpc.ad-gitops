#!/bin/bash
# Makes a test VM from a stopped VM bundle with an APFS clone (no extra disk space until it diverges).
# UTM passes its VM UUID to QEMU as the SMBIOS UUID, which is the hardware UUID Fleet matches hosts on (S-3b checks this).
#   new  - new UUID: Fleet sees a new laptop. Use from the golden VM (E tests).
#   same - same UUID: Fleet sees the same host. Use for W tests from an after-E clone; only one copy may run at a time,
#          and UTM can only list one, so the source is moved aside in UTM's list (it stays on disk).
# Usage: vm/clone.sh new|same <from> <to>
set -euo pipefail
MODE="$1"; FROM="$2"; TO="$3"
DOCS=~/Library/Containers/com.utmapp.UTM/Data/Documents; U=/Applications/UTM.app/Contents/MacOS/utmctl
[ -d "$DOCS/$FROM.utm" ] || { echo "no $FROM"; exit 1; }; [ -e "$DOCS/$TO.utm" ] && { echo "$TO exists"; exit 1; }
$U status "$FROM" 2>/dev/null | grep -q stopped || { echo "$FROM must be stopped"; exit 1; }
cp -c -R "$DOCS/$FROM.utm" "$DOCS/$TO.utm"
/usr/libexec/PlistBuddy -c "Set :Information:Name $TO" "$DOCS/$TO.utm/config.plist"
case "$MODE" in
  new)  # New UUID (a new laptop to Fleet) and a new MAC, so two clones can share UTM's network.
         mac=$(printf '02:%02X:%02X:%02X:%02X:%02X' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
         /usr/libexec/PlistBuddy -c "Set :Information:UUID $(uuidgen)" -c "Set :Network:0:MacAddress $mac" "$DOCS/$TO.utm/config.plist" ;;
  same) echo "Same UUID as $FROM. In UTM, remove $FROM from the list (keep files), then open $TO." ;;
  *) echo "mode must be new or same"; rm -rf "$DOCS/$TO.utm"; exit 1 ;;
esac
echo "Cloned $FROM -> $TO ($MODE): $DOCS/$TO.utm"
