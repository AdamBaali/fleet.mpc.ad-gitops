# D-1: what Fleet claims (docs and code)

- **Date:** 2026-10-08
- **Objective:** Read the Linux disk encryption docs and code before testing.
- **Expected:** A list of supported distros and what orbit does.

## Steps and evidence
- `01`: the server's `IsLUKSSupported` accepts ubuntu, zorin, Fedora, **and** arch, archarm, manjaro, manjaro-arm, cachyos, omarchy.
- `02`: the docs list Ubuntu, Kubuntu and Fedora only.
- `03`: orbit validates the user's passphrase against any keyslot, picks the next free slot, **adds** a keyslot with a random passphrase, and escrows it. It needs `zenity` or `kdialog`. Nothing removes or edits the user's slot.
- `04`: open PR #55070 reduces eligibility to Ubuntu, Zorin and Fedora: the Arch family and Omarchy were accepted by the server, but "No user could complete escrow on them".
- `05`: issue #55069 (Omarchy): the escrow flow doesn't work end to end today (Wayland dialog environment, no zenity or kdialog, lsblk mountpoints).

## Result: PASS

Q3 (desk answer): Fleet does **not** support key escrow on Arch. A real Arch VM test is still planned to show where it breaks.
