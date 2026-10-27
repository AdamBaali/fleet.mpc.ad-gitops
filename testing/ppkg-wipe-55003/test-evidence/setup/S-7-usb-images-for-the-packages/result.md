# S-7: USB images for the packages

- **Started:** 2026-10-26T17:54:38Z
- **Objective:** One FAT32 image per package with the .ppkg at its root
- **Expected:** Two images, one .ppkg each

## Steps and evidence
- `01-images.txt`: `tools/usb-image.sh out/fleet-agent-b.ppkg out/usb-pkg-b.img; tools/usb-image.sh out/fleet-agent-n.ppkg out/usb`

## Result: PASS

Two 64 MB FAT32 images, one package at the root of each (01). The unencrypted packages used in the tests got images the same way (`out/usb-pkg-b-plain.img`, `out/usb-pkg-n-plain.img`).
