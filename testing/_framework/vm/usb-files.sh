#!/bin/bash
# Puts files at the root of a FAT32 disk image, to hot-plug into a QEMU VM (qmp.sh <vm> usb <img> true).
# Usage: vm/usb-files.sh <out.img> <size MB> <file> [file ...]
# Size it above the files' total plus about 10%: UTM's guest tools installer alone is about 80 MB.
set -euo pipefail
out=$1 size=$2; shift 2
rm -f "$out" "$out.dmg"
hdiutil create -quiet -size "${size}m" -fs MS-DOS -volname LABUSB -layout MBRSPUD "$out.dmg"
mnt=$(hdiutil attach -nobrowse "$out.dmg" | awk '/LABUSB/{print $NF}')
trap 'hdiutil detach -quiet "$mnt" 2>/dev/null || true' EXIT
cp "$@" "$mnt/"
ls -l "$mnt"
hdiutil detach -quiet "$mnt"; trap - EXIT
# QEMU wants a raw image.
hdiutil convert -quiet "$out.dmg" -format UDTO -o "$out.cdr" && mv "$out.cdr" "$out" && rm -f "$out.dmg"
echo "$out"
