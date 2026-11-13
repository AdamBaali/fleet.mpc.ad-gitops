# Windows hosts

How to build, drive, enroll, and reset Windows 11 arm64 test hosts on an Apple silicon Mac. Read
[../vm/README.md](../vm/README.md) first: it holds the QEMU tools, the display and USB rules, and the timings.

Sources: `testing/ppkg-wipe-55003`, `testing/bitlocker-pin-42318`, `testing/intune-entra-ids-44916`,
`testing/conditional-access-54654`. The newest method is ppkg-wipe-55003 (October 2026).


## Pick the tool

| Job | Use |
|---|---|
| Install Windows once | UTM, with an answer ISO (`Autounattend.xml`) |
| Run every test host | Homebrew QEMU with `vm/qemu-boot.sh`, on an overlay of the base disk |
| Run a command in the guest | `vm/qga.sh <vm> '<powershell>'` (runs as SYSTEM) |
| Reset, generalize, or re-enroll | Homebrew QEMU only. UTM 4.7.5 hangs at "Start boot option" afterwards |
| Tests that need a TPM (BitLocker) | UTM with `TPMDevice true`. Don't quit or restart UTM while other labs run |

The older projects used UTM everywhere (`win-run.sh`, `qmp.py`, `qga-cmd.py`). Those still work for UTM VMs. For new work,
use `vm/qga.sh` and `vm/qmp.sh`.


## Build the base disk

1. Make the VM in UTM: `osascript testing/ppkg-wipe-55003/vm/create-vm.applescript <name>`.
2. Quit UTM, then copy the Windows ISO and the answer ISO into the VM bundle's `Data/` folder with `cp -c`.
   UTM's sandbox can read them there.
3. Make the answer ISO: `hdiutil makehybrid -o answer.iso <dir> -iso -joliet -default-volume-name ANSWER`.
4. Boot, and press space about 14 times to get past "Press any key to boot from CD".
5. The answer file (`testing/ppkg-wipe-55003/vm/answer/Autounattend.xml` is the newest copy) sets the LabConfig bypass
   keys, three partitions, the public KMS Pro key, a local admin `lab` and a standard user `labuser`, and
   `PreventDeviceEncryption`. Without that last setting, Windows auto-encrypts on a new TPM, and the first build failed
   with `0xED UNMOUNTABLE_BOOT_VOLUME`.
6. The first-logon command runs `setup.ps1` from the answer ISO. It installs the UTM guest tools silently
   (`utm-guest-tools-*.exe /S`), which give qemu-ga, NetKVM, and viogpudo.
7. Use the ppkg variant (windowsPE and specialize only) when the test needs a host that stops at the region screen, like
   a new laptop.
8. Shut down. That disk is the base. `qemu-boot.sh` never writes to it.

Keyboard layout: use en-US in the answer file. The older en-GB files type `\`, `|`, and `"` wrongly.

Clones: `qemu-boot.sh <vm> <base.qcow2>` makes an overlay with its own SMBIOS UUID, serial, and MAC. Run
`sysprep /generalize /oobe /shutdown` in each VM before it enrolls. Clones that share an MDM hardware ID take over each
other's Fleet MDM record.


## Run commands in the guest

```bash
vm/qga.sh win1 'Get-ComputerInfo | Select-Object OsName,OsBuildNumber'
vm/qga.sh win1 "$(cat my-script.ps1)"            # long scripts: pass a file, nested quoting loses backslashes
vm/qga-push.sh win1 ./file.msi 'C:\Windows\Temp\file.msi'   # prints the SHA-256
```

Other routes:
- Fleet live queries and Fleet scripts. They work after a reset, when the guest agent is gone.
- Local MDM commands with no Fleet: `MDM_RemoteWipe` through a CimSession in `root\cimv2\mdm\dmmap`, as SYSTEM. Prove the
  lab can reset before you test Fleet (`testing/ppkg-wipe-55003/payloads/local/wipe-persist-local.ps1`).
- `osqueryi` in the guest: `testing/intune-entra-ids-44916/scripts/vm-query.sh <vm> <sql-file>`.
- A GUI app on the signed-in user's desktop from SYSTEM: `testing/bitlocker-pin-42318/tools/win-gui.sh`. It registers a
  one-off scheduled task with an interactive principal.
- Facts for the first evidence item: `testing/_framework/hosts/host-facts.ps1`.

Files out of a host after a reset: hot-plug a FAT32 USB image as removable (`qmp.sh <vm> usb <img> true`) and copy from it
with a Fleet script.


## Enroll in Fleet

Build the MSI with the enroll secret read from a git-ignored file. Docker must be running.

```bash
fleetctl package --type=msi --arch=arm64 --fleet-url="$FLEET_URL" --enroll-secret="$SECRET" \
  --fleet-desktop --enable-scripts --disable-open-folder
msiexec /i fleet-osquery.msi /qn /norestart       # in the guest
```

Flags seen in the labs: `--bypass-end-user-auth`, `--disable-setup-experience` (provisioning packages),
`--orbit-channel=<x> --desktop-channel=<x>` to pin an older fleetd. Example scripts:
`testing/ppkg-wipe-55003/tools/build-msis.sh`, `testing/bitlocker-pin-42318/tools/build-windows-msi.sh`. See
[fleet-and-packages.md](fleet-and-packages.md) for secrets.

First detail query results arrive about 8 minutes after enrollment.


## Screenshots and input

- Headless QEMU: `vm/qmp.sh <vm> shot out.png`, `keys`, `type`, `click x y`. `click` takes screenshot pixels.
- `vm/qmp.sh <vm> shell` opens a command prompt over Windows setup (Shift+F10) and clicks its title bar for focus.
- `vm/qemu-watch.sh <dir> <vm> <minutes> [stop]` keeps every changed screen while a VM resets.
- UTM windows: `winid` plus `screencapture -x -o -l<id>`. Never capture the whole screen.
- Forward slashes in `cd /d C:/Windows/System32`. Windows setup lists need clicks, not Enter.


## BitLocker and TPM

- Upstream QEMU's arm TPM device fails under HVF. VMs run without a TPM unless `TPM=1`, which was not usable in the labs.
- UTM's `TPMDevice true` gives a working swtpm 2.0. Use it for BitLocker tests.
- BitLocker won't add a TPM protector while a bootable ISO is attached: `testing/bitlocker-pin-42318/vm/detach-isos.sh`.
- Fleet re-enables protection you suspend.
- Fleet showed "verified" for a volume whose recovery key could not unlock C:. Check the key itself.
- The MDM WMI bridge refuses writes to a node Fleet's enrollment owns.
- Duo Desktop on Windows worked only with no TPM in the VM.


## Timings (Windows 11 26H2 arm64, M-series Mac, 4 vCPU, 6 GB)

| Step | Time |
|---|---|
| New VM install | about 40 minutes |
| sysprep generalize to the region screen | about 1 minute |
| `doWipePersistProvisionedData` | 11.5 to 13 minutes |
| `doWipeCloudPersistProvisionedData` | about 36 minutes download, then about 21 minutes reset |
| Overlay size after a reset | 7 to 10 GB local, about 39 GB cloud |


## Mistakes that cost hours

- Starting QEMU inside a short tool call. It dies with the call. Use `FG=1` in a long-lived background task.
- Power cycling during a reset. Windows stayed unbootable. Shut down with `qga.sh <vm> 'Stop-Computer -Force'`.
- A removable USB drive present at boot: setup applied the package and failed with 0x800700b7. A fixed USB disk during
  sysprep gave 0xc0000001. Hot-plug at the region screen.
- virtio-gpu with a generalize: first boot fails with 0xc0000001. Use ramfb.
- Removing the guest-tools drivers from a live image made it unbootable.
- Mac sleep paused every VM and added 35 minutes. Run `caffeinate -dims`.
- `ICD.exe` fails with "too many parameters" when the store file path has spaces. `+Encrypted` packages failed with
  0x80070490.
- `fleetctl mdm run-command` rejects a payload wrapped in `<syncml>`. Send a bare `<Exec>`.
- `fleetctl api -F` sends flat fields only. Use `testing/ppkg-wipe-55003/tools/fleet-post.py` for nested JSON.
- A Windows SCEP challenge allows only letters, digits, and `' ( ) + , - . / : = ?`.
- Entra has no `DeviceId` registry value. Use the `MS-Organization-Access` certificate subject.
- Check the active `fleetctl` context before any command.
