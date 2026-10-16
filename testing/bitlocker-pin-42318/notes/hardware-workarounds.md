# Getting around the physical-hardware tests (research 2026-10-15 22:50)

Two tests are blocked on real hardware: (1) the pre-boot PIN screen (and pre-boot lockout), (2) the customer's "only USB is
offered" symptom. Research by a sub-agent (sources below), checked against the VM's own signals.

## What the VM looks like to Windows (`test-evidence/hw-workaround/01-platform-signals.txt`)
PowerDeterminePlatformRoleEx = 1 (Desktop), chassis type 1 (Other), PCSystemType 1, no S0 Low Power Idle (not Modern Standby),
HID keyboard present. So Windows has no reason to hide the PIN option here: that's why the bug didn't reproduce.

## (2) "Only USB": how Windows decides
- BitLocker hides the PIN/password options on **slates** unless `SystemDrivesEnablePrebootInputProtectorsOnSlates` is enabled
  (Microsoft BitLocker CSP). The decision is "is this a tablet", not "is a keyboard attached"; error 0x803100B5 when adding a PIN
  (NSA BitLocker guidance, github.com/nsacyber/BitLocker-Guidance).
- A clamshell Surface Laptop 7 reports **"Platform Role: Slate"** in System Information and hits 0x803100B5
  (learn.microsoft.com/answers/questions/2132355). So clamshell laptops can be "slates".
- Platform role comes from the ACPI FADT `Preferred_PM_Profile` (8 = Tablet) (PowerDeterminePlatformRoleEx docs). Inference,
  not proven: Slate = FADT profile 8.
- QEMU hard-codes `Preferred_PM_Profile` = 0 (`hw/acpi/aml-build.c` `build_fadt`), and `-acpitable` doesn't apply on arm virt. No
  UTM setting or Windows registry value changes it.
- **Customer check (cheap, best first step):** ask for `msinfo32` "Platform Role" on an affected laptop (alongside `powercfg /a`).
  If it says Slate, profile D is the fix to try.

## (1) Pre-boot PIN screen in a VM
- No report of a working pre-boot PIN on Windows ARM64 in UTM, Parallels or Fusion. One Parallels (M3) report: PIN never asked,
  then "no pre-boot keyboard found" (forum.parallels.com/threads/bitlocker-pin-wird-nicht-abgefragt.368196).
- x86_64 QEMU + OVMF + swtpm runs BitLocker (blog.scrt.ch 2024-10-28, TPM sniffing with PIN), but the PIN screen isn't explicitly
  documented; UTM's x86 emulation on Apple Silicon is very slow.
- Cloud VMs (Azure/AWS/GCP): no interactive pre-boot console; Microsoft says Azure VMs can't do the BitLocker boot prompt.
- Our notes say a TPM-only reboot was never observed in UTM either, so the hang may be bootmgr + TPM unseal on UTM/ARM, not the
  PIN screen.

## Options, ranked
| # | What | Effort | Disk | Odds | Risk |
|---|---|---|---|---|---|
| 1 | Ask the customer for `msinfo32` Platform Role + `powercfg /a` on an affected laptop | minutes (CSM) | 0 | high | none |
| 2 | Diagnose the UTM hang: suspend BitLocker on `bitlocker-lab` (key in the clear), reboot (should boot); then `bcdedit /set {bootmgr} displaybootmenu yes` + timeout and reboot TPM-only to see whether bootmgr draws/accepts keys | 1 h | 0 | medium | changes the evidence VM's protection state (Fleet may stop showing Verified); the PIN protector must be replaced by TPM-only first |
| 3 | Patched QEMU (one line: FADT profile 8 = Tablet), built on the Mac, HVF, edk2 + Homebrew swtpm, on an APFS clone of the VM disk (BitLocker suspended first) -> expect "Platform Role Slate" and "only USB"; then profile D | 2–3 h | ~5 GB build + clone growth | medium–high | Homebrew installs (qemu deps, swtpm); no UTM change |
| 4 | x86_64 Windows 11 in UTM emulation (OVMF + TPM) for the pre-boot PIN screen | half a day+ | ~30–64 GB | medium | not enough free disk now (30 GB, LUKS lab pauses at 15 GB) |
| 5 | Parallels trial | 1–2 h | ~30 GB | low–medium | one report says no PIN prompt; disk |

## Outcome (2026-10-15 23:15 – 2026-10-16 00:35)
- (1) Pre-boot: **not hardware-only.** UTM shows the BitLocker PIN and recovery screens (Return = `\r`); lockout seen: the 6th
  wrong PIN in one boot goes to recovery.
- (2) "Only USB": **reproduced** with option 3 (patched QEMU, profile 8 = Slate): 0x803100B5 without the slates setting, OK with
  it; desktop control OK. See EVIDENCE "Tablet (slate) VM". Option 1 (customer's `msinfo32` Platform Role) still worth doing.
- Not done: TPM+PIN in the standalone QEMU (TPM not usable there; `ppi=off` workaround), profile D delivered through Fleet.
