# K-4: reboot with only the escrowed key

- **Date:** 2026-10-16
- **Objective:** Q1: with the user's slot removed, does the escrowed key boot the machine?
- **Expected:** Yes. IT can unlock it.

## Steps and evidence
- `01-unlock-prompt-before-typing.png`: the boot console about 35 s after the VM started: the unlock prompt (nothing typed yet).
- `02-after-unlock.txt`: after the escrow key was typed (by `tools/unlock-watch.sh`, started by Adam) the guest is up, root on the LVM volume, data hash unchanged (M-3), only keyslot 1 present, the user's passphrase still rejected.

## Result: PASS
