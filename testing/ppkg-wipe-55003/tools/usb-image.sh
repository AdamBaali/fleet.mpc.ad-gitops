#!/bin/bash
# Puts one .ppkg at the root of a small FAT32 disk image, for a UTM removable USB drive (TEST_PLAN S-7).
# Usage: tools/usb-image.sh <package.ppkg> <out.img>
set -euo pipefail
PKG="$1"; OUT="$2"
[ -f "$PKG" ] || { echo "no $PKG"; exit 1; }
rm -f "$OUT" "$OUT.dmg"
hdiutil create -quiet -size 64m -fs MS-DOS -volname PPKG -layout MBRSPUD "$OUT.dmg"
M=$(hdiutil attach -nobrowse "$OUT.dmg" | awk '/PPKG/{print $NF}')
cp "$PKG" "$M/"; ls -la "$M"; hdiutil detach -quiet "$M"
# UTM wants a raw image.
hdiutil convert -quiet "$OUT.dmg" -format UDTO -o "$OUT.cdr" && mv "$OUT.cdr" "$OUT" && rm -f "$OUT.dmg"
echo "Wrote $OUT. Copy it into the VM bundle's Data/ (cp -c) and set it as ImageName on Drive 3 in config.plist with UTM closed, or pick it in the VM's USB drive menu while it runs."
