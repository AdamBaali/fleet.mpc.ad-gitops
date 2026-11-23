# Windows VMs on a Mac

How to run Windows 11 arm64 test hosts on an Apple silicon Mac with free tools, headless, and scriptable. Written after
the ppkg-wipe-55003 lab lost a day to UTM. Use this for any test that resets, generalizes, or re-enrolls a Windows host.


## Use Homebrew QEMU, not UTM

UTM 4.7.5 hangs at "Start boot option" on the first boot after a Windows reset or sysprep generalize. Power cycling
does not help. The same disk boots on Homebrew QEMU 11.1.2 with Homebrew's edk2 firmware.

- utmapp/UTM#7648 tracks the hang. It is open and still present in the UTM 5.0 betas.
- The fault is in UTM's QEMU and edk2 build, not in Windows: the same overlay boots on Homebrew QEMU (ppkg-wipe-55003
  L-2C, L-3).
- Install Windows in QEMU too (`qemu-install.sh`). On macOS 27, Claude Code can't read UTM's folder (see below).

VMware Fusion and Parallels are paid or need an account, so the lab doesn't use them.

```bash
brew install qemu swtpm tesseract
python3 -m pip install --user pillow   # for ocr.py
```


## macOS 27 and Claude Code

The lab ran on macOS 15 until November 2026. These changed with macOS 27 (windows-mdm-migration-59195):

- **UTM's folder is closed to Claude.** `~/Library/Containers/com.utmapp.UTM` returns "Operation not permitted" to
  QEMU, `cp`, and `ls` started by Claude Code, even with the sandbox off. Full Disk Access on Claude.app doesn't help:
  Claude.app starts Claude Code through a helper (`disclaimer`) that makes the embedded app under
  `~/Library/Application Support/Claude/claude-code/<version>/` the one macOS checks, and that path changes with every
  update. Keep base disks and ISOs in `~/Documents/fleet-lab/` (`base/`, `iso/`), never in a UTM bundle.
- **Socket paths have a 104-byte limit.** QEMU refuses a `qmp.sock` or `qga.sock` path longer than that, and a
  project's `out/qemu/` is too deep. The tools now default `VM_ROOT` to `~/Documents/fleet-lab/vm`.
- **Base disks can disappear.** The lab's only base disk lived inside a UTM bundle and was gone after the upgrade, which
  orphaned every overlay built on it. Check that the base disk exists before planning a test (`qemu-img info`).
- **Python isolation hides Pillow.** `python3 -I` skips user site-packages, where `pip install --user` puts Pillow, so
  `screen.sh` runs `ocr.py` with `-E`.
- **oh-my-zsh eats the first character.** A pending "Would you like to update? [Y/n]" prompt reads the first key of a
  command typed into a new terminal tab (`mkdir` ran as `kdir`). Run `omz update` once before sending commands to the
  terminal panel.


## Tools

All take a VM name. Each VM lives in `$VM_ROOT/<name>/` (default `~/Documents/fleet-lab/vm/`). Run them from the
project folder, or link them into the project's `tools/`: they resolve symlinks, so link only the scripts you call.

| Tool | Does |
|---|---|
| `qemu-install.sh <vm> <base.qcow2> <windows.iso> <answer.iso>` | Installs Windows onto a new base disk from USB CD-ROMs |
| `qemu-boot.sh <vm> <base.qcow2>` | Starts a VM on an overlay of the base disk, with its own MAC, SMBIOS UUID, and serial |
| `usb-files.sh <out.img> <MB> <file>...` | FAT32 image with the files at its root, to hot-plug with `qmp.sh <vm> usb <img> true` |
| `qmp.sh <vm> shot <png>` | Screenshot. Also `keys`, `type`, `click x y`, `shell` (Shift+F10 at setup), `usb`, `unusb`, `quit`, raw QMP JSON |
| `qga.sh <vm> '<powershell>'` | Runs PowerShell as SYSTEM through the guest agent and prints its output |
| `qga-push.sh <vm> <file> <guest path>` | Copies a file into the VM and prints its SHA-256 |
| `qemu-watch.sh <dir> <vm> <minutes> [stop]` | Keeps every new screen as evidence while a VM resets, with a log |
| `screen.sh <vm> text\|find\|click\|wait\|still\|look` | Reads the screen with local OCR (`ocr.py`): wait for text, click a label, small picture for Claude |

Socket files per VM: `qmp.sock` (QEMU control), `qga.sock` (guest agent). VNC listens on `127.0.0.1:590$VNC` for a person.


## Base disk

1. Get the Windows 11 Arm64 ISO from microsoft.com/software-download/windows11arm64: pick the multi-edition ISO, then
   "English (United States)" to match the answer file. The link lasts 24 hours. The 26300 build is 8.5 GB.
2. Get UTM's guest tools ISO (getutm.app/downloads/utm-guest-tools-latest.iso, about 120 MB). It has qemu-ga, NetKVM,
   vioserial, and viogpudo. Windows on arm64 has no inbox virtio network driver, so without it the VM has no network.
3. Build the answer ISO from `vm/answer/` and install:
   `FG=1 vm/qemu-install.sh <name> ~/Documents/fleet-lab/base/<name>.qcow2 <windows.iso> answer.iso` as a background
   task, then `qmp.sh <name> keys spc` a few times so the firmware boots the CD. Send no more keys after setup starts:
   stray spaces opened a "Support Link" dialog. Setup stops at the region screen.
4. At the region screen, put the guest tools installer on a USB image (`usb-files.sh`), hot-plug it as removable, open
   `qmp.sh <name> shell`, and run the installer with `/S`.
5. Shut down. The disk image is the base. `qemu-boot.sh` never writes to it.

Every VM gets its own SMBIOS UUID and serial, but clones of a disk that already ran specialize share a Windows MDM
hardware ID, and a second clone takes over the first one's MDM record in Fleet. Run `sysprep /generalize /oobe
/shutdown` in each VM before enrolling it.


## Rules that save hours

Start and stop:
- Run QEMU as a long-lived background task: `FG=1 qemu-boot.sh <vm> <base>`. A QEMU started inside a short tool call
  dies with it.
- Shut down with `qga.sh <vm> 'Stop-Computer -Force'` or `qmp.sh <vm> '{"execute":"system_powerdown"}'`. Never
  power cycle a VM in the middle of a reset; it left Windows unbootable.
- `pgrep -f <vm>` matches its own command line. Check the `pid` file instead.
- Keep the Mac awake for the whole run (`caffeinate -dims` in a terminal, or the app's keep-awake). An idle sleep
  pauses every VM, so a reset takes 35 minutes longer and the timings are wrong (ppkg-wipe-55003 X-2).
- Start `qemu-watch.sh` after QEMU has written its `pid` file; it stops when that process is gone.
- A VM that shows Automatic Repair is lost; make a new one from the base disk. One went there after its last run
  with `GPU=virtio` and a Mac sleep during boot; the cause wasn't isolated (ppkg-wipe-55003 X-4, attempt 1).

Display:
- Use ramfb only (the default). With virtio-gpu attached, the first boot after generalize fails with 0xc0000001 and a
  reset sits idle with no picture.
- ramfb can show stale or black screens on the desktop under HVF. If no reset follows, restart with `GPU=virtio` for a
  correct picture.

TPM:
- Upstream QEMU's arm TPM device crashes under HVF. VMs run without one (`TPM=1` to try). BitLocker tests need another
  plan: see the project's notes.
- Without a TPM, setup stops at "This PC doesn't currently meet Windows 11 system requirements". The answer file in
  `vm/answer/` sets `BypassTPMCheck`; older project copies (ppkg-wipe-55003, bitlocker-pin-42318) don't, since they
  installed in UTM with its TPM.

USB drives:
- A removable USB drive present at boot makes Windows setup apply a provisioning package by itself, which ended in
  Provisioning failure 0x800700b7 here.
- A fixed USB disk present during sysprep's reboot gave 0xc0000001.
- What works: boot without it and hot-plug it at the region screen (`qmp.sh <vm> usb <img> true`).
- Hot-plug it as removable (`true`). Hot-plugged as fixed, Windows didn't see the disk at all (ppkg-wipe-55003 X-6).
- After a reset the guest agent is gone. To get a file onto the host then, hot-plug a USB image and copy it with a
  Fleet script.

Typing and clicking:
- `qmp.sh <vm> shell` opens a command prompt over Windows setup and clicks its title bar, which gives it focus.
  Without that click, letters are lost.
- In some images' keyboard layouts, `\` types as `#`. Use forward slashes (`cd /d C:/Windows/System32`).
- `click` sends move, press, and release with pauses. Windows drops a click sent in one burst. In setup lists, Enter
  only selects; click the buttons.

Guest agent:
- Prefer `qga.sh` over typing. Put long PowerShell in a file and pass `"$(cat file.ps1)"`; nested shell quoting loses
  backslashes.
- A reset removes the guest tools, so the agent is gone afterwards. `qemu-watch.sh` uses that: the agent answering
  again with a new hostname means Windows is back. After a reset, use screenshots and Fleet live queries.

Local MDM commands (no Fleet needed):
- `MDM_RemoteWipe` and other CSPs work locally through the MDM WMI bridge: a CimSession in the
  `root\cimv2\mdm\dmmap` namespace, as SYSTEM (`qga.sh`), with typed `CimMethodParameter` values. Use it to prove the lab
  can reset before testing Fleet.


## Timings seen (Windows 11 26H2 arm64, M-series Mac, 4 vCPU, 6 GB)

| Step | Time |
|---|---|
| `qemu-install.sh` to "Please keep your computer on" (macOS 27, QEMU 11.1.2) | about 57 minutes. Setup read 9.25 GB from the USB CD-ROM at about 2.7 MB/s on average. In that phase the vCPUs were about 20% busy, the disk had no flushes, and QEMU's main thread sat at 100% CPU emulating USB storage. Next time, try `usb-uas` instead of `usb-storage` for the CDs |
| sysprep generalize to the region screen | about 1 minute |
| `doWipePersistProvisionedData` to the region screen | 11.5 to 13 minutes |
| `doWipeCloudPersistProvisionedData` | about 36 minutes download, then about 21 minutes reset |
| Disk per VM overlay after a local reset | 7 to 10 GB |
| Disk per VM overlay after a cloud reset | about 39 GB |
