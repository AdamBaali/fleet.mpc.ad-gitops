# L-2B: Arm B: generalize an image that never had the guest tools

- **Started:** 2026-10-26T23:25:07Z
- **Objective:** Fresh Windows 11 26H2 install from the ISO, no UTM guest tools, sysprep generalize at the region screen, then cold-boot a clone
- **Expected:** Clone boots to the region screen

## Steps and evidence
- `01-build.txt`: `ISO=$HOME/Downloads/win11-iso/Windows11_Client_arm64_en-us_26300_9457.iso vm/build-golden.sh ppkg-golden-v0`

## Result: INFO

Stopped during the install: superseded by L-2C, which showed the hang is UTM QEMU/edk2, so the guest tools question no longer matters.

_Finished 2026-10-27T00:08:47Z_
