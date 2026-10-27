# S-7: USB images for the packages

- **Started:** 2026-10-26T17:54:38Z
- **Objective:** One FAT32 image per package with the .ppkg at its root
- **Expected:** Two images, one .ppkg each

## Steps and evidence
- `01-images.txt`: `tools/usb-image.sh out/fleet-agent-b.ppkg out/usb-pkg-b.img; tools/usb-image.sh out/fleet-agent-n.ppkg out/usb`
