# K-4: reboot with only the escrowed key

- **Date:** 2026-10-16
- **Objective:** Q1: with the user's slot removed, does the escrowed key boot the machine?
- **Expected:** Yes. IT can unlock it.

## Steps and evidence
- No prompt screenshot here: the script was started from a Terminal without screen-recording permission, so it could not capture the screen. The unlock prompt and the rejected passphrase are shown in `../K-3-reboot-old-passphrase-rejected/02-unlock-prompt-after-old-passphrase-typed.png`.
- `02-after-unlock.txt`: after the escrow key was typed (by `tools/unlock-watch.sh`, started by Adam) the guest is up, root on the LVM volume, data hash unchanged (M-3), only keyslot 1 present, the user's passphrase still rejected.

## Result: PASS
