#!/bin/bash
# Makes a new laptop from the golden VM with a package on its USB drive, boots it to the region screen, and opens the
# package from Shift+F10 (UTM's USB disk isn't removable media, so setup doesn't offer it; see E-1). Stops at the
# "Is this package from a source you trust?" prompt and prints the screenshot path.
# Usage: tools/apply-pkg.sh <test-id> <vm> <usb image> <ppkg file name>
set -euo pipefail
ID="$1"; V="$2"; IMG="$3"; PKG="$4"
export PATH=$HOME/.local/bin:$PATH
vm/clone.sh new ppkg-golden-oobe "$V" >/dev/null
vm/attach-usb.sh "$V" "$IMG" >/dev/null
open -g -a UTM "$HOME/Library/Containers/com.utmapp.UTM/Data/Documents/$V.utm"; sleep 4
/Applications/UTM.app/Contents/MacOS/utmctl start "$V" >/dev/null 2>&1 || true
for i in $(seq 1 60); do tools/vm-exec.sh "$V" '"up"' 20 2>/dev/null | grep -q up && break; sleep 5; done
sleep 20
tools/shot.sh "$ID" region-screen UTM "$V"
tools/vm-input.sh "$V" shell; sleep 5; tools/vm-input.sh "$V" click 499 399; sleep 1
tools/vm-input.sh "$V" run "D:"; sleep 1; tools/vm-input.sh "$V" run "start $PKG"; sleep 12
tools/shot.sh "$ID" trust-prompt UTM "$V"
