# Windows hosts

Windows 11 arm64 on the Mac. Read [../vm/README.md](../vm/README.md) for the QEMU tools, display and USB rules, and timings.

| Job | Use |
|---|---|
| Install Windows once | UTM with an answer ISO (`testing/ppkg-wipe-55003/vm/answer/Autounattend.xml`, en-US, `PreventDeviceEncryption`) |
| Run test hosts | Homebrew QEMU: `FG=1 vm/qemu-boot.sh <vm> <base.qcow2>` (UTM hangs after a reset or generalize) |
| Needs a TPM (BitLocker) | UTM with its TPM. QEMU's TPM is unusable under HVF |

## Use
```bash
vm/qga.sh <vm> "$(cat script.ps1)"                 # PowerShell as SYSTEM
vm/qga-push.sh <vm> ./file.msi 'C:\Windows\Temp\file.msi'
vm/qmp.sh <vm> shot out.png                        # also keys, type, click x y, shell, usb
vm/qemu-watch.sh <dir> <vm> <minutes>              # keeps every new screen while a VM resets
vm/qga.sh <vm> "$(cat testing/_framework/hosts/host-facts.ps1)"   # first evidence item
```
After a reset the guest agent is gone: use Fleet scripts and live queries, or a hot-plugged USB image.

## Enroll
`fleetctl package --type=msi --arch=arm64 ... --fleet-desktop --enable-scripts` (Docker running), then `msiexec /i x.msi /qn /norestart`. Examples: `testing/ppkg-wipe-55003/tools/build-msis.sh`. First detail results arrive in about 8 minutes. Run `sysprep /generalize /oobe /shutdown` in each clone first, or clones take over each other's MDM record.

## Gotchas
- Start QEMU as a long-lived background task. Keep the Mac awake (`caffeinate -dims`).
- Never power cycle during a reset. Use ramfb, not virtio-gpu, for a VM that generalizes.
- A removable USB at boot makes setup apply the package (0x800700b7). Hot-plug it as removable at the region screen.
- Windows setup types `\` and `"` wrongly on some layouts: use forward slashes or `qga.sh`.
- BitLocker: detach ISOs before adding a TPM protector (`testing/bitlocker-pin-42318/vm/detach-isos.sh`). Fleet re-enables protection you suspend. "Verified" in Fleet doesn't prove the recovery key works.
- `fleetctl mdm run-command` rejects `<syncml>`-wrapped payloads: send a bare `<Exec>`. `fleetctl api -F` sends flat fields only: use `testing/ppkg-wipe-55003/tools/fleet-post.py`.
- Check the active `fleetctl` context before any command.

Timings: install about 40 min, sysprep to region screen 1 min, local reset 12 min, cloud reset about 57 min.
