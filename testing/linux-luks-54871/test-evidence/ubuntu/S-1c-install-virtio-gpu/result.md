# S-1c: second Ubuntu desktop install attempt (VM `luks-ubuntu2`, since deleted)

- **Date:** 2026-10-15
- **Objective:** Get the desktop installer working on a new VM and follow the end user guide.
- **Expected:** An encrypted LVM install.

## Steps and evidence
- `01`-`16`: new VM with an NVMe disk. With **virtio-ramfb** the live desktop was black; with **virtio-gpu-pci** the installer ran. Pages to the **Create a passphrase** page (Use LVM and encryption selected).
- `22`, `25`: nobody was at the screen to type credentials, so it switched to Automated installation with a config URL. Screenshots of the review page were deleted (it prints the config including the passphrase).
- `30`: copying files. About 28 minutes later the installer showed "Something went wrong" (system program problem, no useful log).

## Result: FAIL

The desktop automated install crashed. Replaced by S-1d (server ISO, which worked). Finding: the Ubuntu desktop live session needs `virtio-gpu-pci`, not `virtio-ramfb`.
