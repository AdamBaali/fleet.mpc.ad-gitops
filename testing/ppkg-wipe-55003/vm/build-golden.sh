#!/bin/bash
# Builds the golden VM (TEST_PLAN S-3): creates it in UTM, adds TPM 2.0, the Windows ISO and the answer ISO (APFS clones
# inside the bundle, so UTM's sandbox can read them), boots the installer. Windows installs on its own and stops at the
# region screen. Then shut it down there and keep the bundle as the golden copy. Usage: vm/build-golden.sh [name]
set -euo pipefail
P="$(cd "$(dirname "$0")/.." && pwd)"; NAME="${1:-ppkg-golden-oobe}"
ISO="${ISO:-$HOME/Library/Parallels/Downloads/26100.4349.250607-1500.ge_release_svc_refresh_CLIENTCONSUMER_RET_A64FRE_en-us.iso}"
DOCS=~/Library/Containers/com.utmapp.UTM/Data/Documents; B="$DOCS/$NAME.utm"; U=/Applications/UTM.app/Contents/MacOS/utmctl
[ -f "$ISO" ] || { echo "Windows ISO not found: $ISO"; exit 1; }
[ -e "$B" ] && { echo "$B exists; move it away first"; exit 1; }
# The plist edit needs UTM closed, which stops every VM. Refuse rather than stop another lab's VM.
if $U list 2>/dev/null | awk 'NR>1 && $2!="stopped"' | grep -q .; then echo "A UTM VM is running; stop it first"; exit 1; fi
free_gb=$(df -g "$DOCS" | awk 'NR==2{print $4}'); [ "$free_gb" -ge 30 ] || { echo "Only ${free_gb} GB free; need 30 GB"; exit 1; }
hdiutil makehybrid -quiet -o "$P/vm/answer.iso" "$P/vm/answer" -iso -joliet -default-volume-name ANSWER -ov
open -g -a UTM; sleep 4
osascript "$P/vm/create-vm.applescript" "$NAME"
osascript -e 'tell application "UTM" to quit'; for i in $(seq 1 20); do pgrep -x UTM >/dev/null || break; sleep 1; done
cp -c "$ISO" "$B/Data/win11-arm64.iso"; cp -c "$P/vm/answer.iso" "$B/Data/answer.iso"
/usr/libexec/PlistBuddy -c "Set :QEMU:TPMDevice true" -c "Add :Drive:1:ImageName string win11-arm64.iso" \
  -c "Add :Drive:2:ImageName string answer.iso" "$B/config.plist"
open -g -a UTM; sleep 4
$U start "$NAME"
# The installer waits for "Press any key to boot from CD".
for i in $(seq 1 14); do osascript -e "tell application \"UTM\" to input keystroke (get virtual machine named \"$NAME\") text \" \""; sleep 1; done
$U status "$NAME"
