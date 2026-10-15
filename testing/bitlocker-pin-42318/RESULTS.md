# Results: #42318 BitLocker PIN (running log, newest at the bottom)

## 2026-10-15
- 12:15 Lab created. Facts in `CLAUDE.md` (Fleet's payload, the relax query, server option on Render, host options).
- 12:27 Host decided (Adam): new Windows 11 ARM VM in UTM.
- 12:30 VM `bitlocker-lab` created by `vm/create-vm.applescript` (4 CPUs, 6 GB, 64 GB NVMe, shared network, ramfb). TPM 2.0 and
  the two ISOs (Windows 11 arm64 26300 from the #54654 lab, and `vm/answer.iso`) set in `config.plist` with UTM quit. ISOs
  cloned into the VM bundle's `Data/` and named by `ImageName`: UTM boots them with no UI step (the #54654 lab had to attach
  ISOs by hand). Unattended install running (`test-evidence/S-setup/`).
- 12:33 Code review of Fleet `main` (cb62bdd782) and tag `fleet-v4.92.3` (the lab's version):
  - With the fleet's disk encryption OFF, Fleet runs none of the BitLocker queries and sends no BitLocker command; no
    escrow, no disk encryption status, no PIN banner. `enable_custom_disk_encryption` only lifts the profile validation
    (`server/fleet/windows_mdm.go:344`). So a custom profile on such a fleet is a clean test of Windows alone, but the
    customer would lose Fleet's recovery key escrow.
  - 4.92.3 PIN command: `SystemDrivesRequireStartupAuthentication` only, all dropdowns 2, `ConfigureNonTPMStartupKeyUsage_Name`
    false; sent by `tpm_pin_config_verify` when `UseTPMPIN` is missing or 0. `main`/4.93 also sends `SystemDrivesMinimumPINLength`
    6, `SystemDrivesEnhancedPIN` enabled, `SystemDrivesDisallowStandardUsersCanChangePIN` disabled, and re-sends if any differ.
  - `bitlocker_startup_policy_relax` (in 4.92.3 too): C: fully encrypted, protection off, no TPM/TPM+PIN/TPM+key/TPM+PIN+key
    protector, `UseTPM` = 0 -> resets all dropdowns to 2. Only on fleets with disk encryption on.
  - **Fleet 4.93.0 (released 2026-10-08, commit b05be8f2f3, issue #49133)**: end users set the PIN on My device; fleetd calls
    `ProtectKeyWithTPMAndPIN` over WMI (`orbit/pkg/bitlocker/bitlocker_management.go:242`). This bypasses Manage BitLocker.
    The lab runs 4.92.3, so this flow isn't testable here without an upgrade.
- 12:34 Microsoft BitLocker CSP docs (updated 2025-11-06), `SystemDrivesRequireStartupAuthentication`: "Devices that pass
  Hardware Security Testability Specification (HSTI) validation or Modern Standby devices won't be able to configure a
  Startup PIN using this CSP. Users are required to manually configure the PIN." `SystemDrivesEnablePrebootInputProtectorsOnSlates`:
  if not enabled, TPM startup PIN options "might not be available" on devices without pre-boot input. Fleet never sends this
  node. Added profile D to test it.
- 12:38 Adam: bump the lab Fleet to 4.93.0 in the same Render redeploy as `FLEET_MDM_ENABLE_CUSTOM_DISK_ENCRYPTION=true`.
- 12:40 **The fleetd half of 4.93's PIN flow is not released.** `orbit/changes/49133-bitlocker-pin-non-admin` is still a pending
  change file; latest fleetd tag is `orbit-v1.61.0` (2026-09-14), older than the fleetd PIN commit aedb9cff91 (2026-09-17).
  `https://updates.fleetdm.com/targets.json` (12:39): `orbit/windows/{stable,edge}` and `orbit/windows-arm64/{stable,edge}`
  are all 1.61.0. Without capability `windows_bitlocker_pin`, Fleet 4.93 shows the old Manage BitLocker instructions
  (`DeviceUserPage.tsx:1061`). So today a customer on 4.93.0 still hits this issue.
- 12:44 Render redeployed by Adam: image 4.93.0 + `FLEET_MDM_ENABLE_CUSTOM_DISK_ENCRYPTION=true`. First API call returned
  HTTP 502 (Render page) at 12:44:0x; from 12:44:11 `/healthz` 200 and `/version` 4.93.0, revision 92732182750b (= tag
  fleet-v4.93.0). The 502 was the deploy switching over, not a failed migration.
- 12:52 Applied only `fleets/windows-bitlocker-lab.yml` with local `fleetctl gitops` (dry run first: "would've applied 1 fleet",
  nothing global). Fleet **7 "Windows BitLocker Lab"** created. Global config and other fleets untouched; the workflow apply
  stays broken by the SCEP proxy error until that's fixed (Adam / #54654 lab).
- 12:53 **S-3 PASS:** `POST /api/v1/fleet/configuration_profiles` with profile A on fleet 7 returned a `profile_uuid` (no
  "can't include BitLocker settings"). Deleted again (fleet had no hosts). `test-evidence/S-setup/S-3-upload-profile-A.txt`.
- 12:54 Baseline settings on fleet 7 via `POST /api/v1/fleet/disk_encryption`: `windows_settings.enable_disk_encryption` true,
  `require_bitlocker_pin` true (macOS `enable_disk_encryption` stays false).
- 12:45-12:53 VM after the "Installing 42%" phase: Windows boot spinner for ~7 min with QEMU at ~300% CPU, then **FAIL: blue
  screen `UNMOUNTABLE_BOOT_VOLUME (0xED)`** ("We'll restart for you"). `test-evidence/S-setup/13-setup.png`. Not forced off
  (the #54654 VM ended in Automatic Repair after a forced stop); watching the automatic restart.
- 12:52 fleetd MSI for fleet 7 built: `out/fleet-osquery-arm64.msi` (gitignored, contains the enroll secret). Starting Docker
  for the build also auto-started the #54654 lab's `pingfederate` and `step-ca` containers (restart policy).
- 12:54-12:57 After the blue screen the VM rebooted and sat on the UEFI "Start boot option" screen for 3+ minutes (QEMU ~230%
  CPU, no Windows spinner). `test-evidence/S-setup/15-boot2-*.png`. Same 26300 ISO as the #54654 VM that also ended in recovery.
- 12:58 Adam: reinstall from the latest official Windows 11 Arm64 ISO. VM force-stopped (broken, being rebuilt).
- 13:07 Latest official Arm64 ISO (microsoft.com/software-download/windows11arm64, "Current release: Windows 11 2026 Update,
  Version 26H2"): `Windows11_Client_arm64_en-us_26300_9457.iso`, Content-Length 8528523264, Last-Modified 2026-09-29. Same name
  and size as the local copy, so not re-downloaded. Rebuild change instead: `PreventDeviceEncryption` (unattend
  `Microsoft-Windows-SecureStartup-FilterDriver` + `HKLM\SYSTEM\CurrentControlSet\Control\BitLocker`), because Windows'
  automatic device encryption with the new TPM is the likeliest cause of the 0xED (unconfirmed). It also leaves the encryption
  to Fleet, as the baseline needs.
- 13:08 Broken VM moved out of UTM to `vm/broken-0xED.utm` (gitignored; kept as evidence, delete when done). A Finder "move to
  Trash" call hung (likely a macOS automation prompt) and was cancelled.
- 13:09 Fresh VM built and started by `vm/build-vm.sh` (same settings, new answer ISO with `PreventDeviceEncryption`). Windows
  Setup booting; watcher screenshots every 2 min to `test-evidence/S-setup2/`.
- 13:12 Adam: start only the #54654 tunnel. Ran `fleet-54654-lab/tools/resume.sh` line 9 (cloudflared, pid 92013; last ran
  2026-10-11). 4 tunnel connections registered; `https://scep.mpc.ad/scep/fleet-scep?operation=GetCACaps` -> 200 x3
  ("Renewal SHA-1 SHA-256 AES DES3 SCEPStandard POSTPKIOperation").
- 13:13 Pushed 47ae168 (fleet 7 baseline in YAML: `windows_settings.enable_disk_encryption` + `require_bitlocker_pin`). Run
  38725593338 **succeeded** ("applied certificate authorities", fleet "Windows BitLocker Lab" applied). Fleet 7 still has both
  settings on; all 5 fleets present. GitOps apply works again.
- 13:20 Pushed GitOps docs commit 114cbec (README fleet row + Known issue, `fleets/windows-bitlocker-lab/README.md`); markdown only, no apply.
- 13:23 **S-1:** second build reached the desktop (Adam saw it; done marker at 13:23:40). No blue screen this time.
- 13:24 **S-1 / S-1b facts** (`test-evidence/S-1/01-host-facts.txt`, `02-tpm.txt`): Windows Pro, 26H2, build 26300.9457; C: Fully
  Decrypted, no protectors, no FVE policy (`PreventDeviceEncryption` held). **Not Modern Standby**: `powercfg /a` "Standby (S0 Low
  Power Idle) The system firmware does not support this standby state"; PCSystemType 1 (Desktop), chassis 1; HID keyboard present;
  WinRE enabled; Secure Boot off. TPM: swtpm ("IBM", 2.0, spec 1.64), `tpmtool`: initialized, owned, Ready For Storage True,
  "Bitlocker PCR7 Binding State: Binding Not Possible". **`Get-Tpm` fails** `0x80284001` and each call logs System Event 15
  (TPM "non-recoverable error"), at the same times as the calls (probably the emulated TPM lacking something `Get-Tpm` asks for;
  unconfirmed). Difference from the customer: their laptops are probably Modern Standby; this VM isn't.
- 13:27 fleetd 1.61.0 installed silently from `out/fleet-osquery-arm64.msi` (copied with `utmctl file push`, SHA-256 matched),
  `msiexec` exit 0 (`test-evidence/S-2/01-install.txt`).
- 13:28 **S-2 PASS:** host 15 `BITLOCKER-LAB` in fleet 7, MDM "On (manual)".
- 13:40 **Mistake (mine):** `AdamBaali/fleet.mpc.ad-gitops` is PUBLIC, and my commit messages f1e3465, 47ae168 and 114cbec
  said `fleetdm/fleet#42318`. GitHub put three "referenced" events from AdamBaali on the public issue timeline (10:50, 11:11,
  11:19 UTC). No secrets or codenames in them. GitHub can't delete timeline events; rewriting history wouldn't remove them.
  From now on, commit messages in public repos name the lab ("#42318 lab"), never `owner/repo#N`.
- 13:40 Research (`notes/research-2026-10-15.md`): open docs PR fleetdm/fleet#43915 (draft) says "Resolves #42318" and still
  says a PIN can only be enforced on unencrypted drives; customer-deebradel doesn't deploy Fleet Desktop, so the 4.93 My
  device PIN form wouldn't reach them; fleetd 1.62 (milestone due 2026-10-02, overdue) carries the PIN capability on branch
  `rc-minor-fleetd-v1.62.0`; fleetd doesn't recognise "no pre-boot keyboard" errors (0x803100B5/B6) and nothing in Fleet checks
  Modern Standby/HSTI/slates. Second Microsoft node Fleet never sends: `SystemDrivesEnablePreBootPinExceptionOnDECapableDevice`.
- 13:36 Fleet's first detail-query results for host 15 took ~8 min to land (`detail_updated_at` was still 2000-01-01 at 13:35
  after a refetch at 13:31; host online).
- 13:37 **S-4 FAIL (lab setup):** fleetd log: `ERR failed to encrypt the volume error="protecting with TPM: protectKeyWithTPM(C:):
  BitLocker Drive Encryption detected bootable media (CD or DVD) in the computer"`. The Windows ISO was still attached as a USB
  CD. Fix: shut down, remove both ISOs from `config.plist`, start again.
- 13:38 Fleet shows host 15 disk encryption **"failed"** with that exact detail (good: the error reaches the admin). fleetd had
  already added a RecoveryPassword protector; C: still Fully Decrypted, Protection Off. OS now reported: Windows 11 Pro 26H2
  10.0.26300.9457.
- 13:39 VM shutting down to remove the ISOs; Windows is installing updates during shutdown ("Updates are underway"), not forced.
- 13:43 VM powered off after Windows updates. `vm/detach-isos.sh`: both CD drives emptied in `config.plist`, VM started, guest
  agent up 13:44. Waiting for fleetd to retry the encryption (the server keeps asking while a client error is recorded).
- 13:44:57 fleetd retried after the restart: C: "Encryption in Progress" 72%, protectors RecoveryPassword + Tpm (TPM protector
  works on UTM's emulated TPM once no bootable media is attached). Fleet: "enforcing".
- 13:46:35 **S-4 (VM side) PASS:** C: "Used Space Only Encrypted" 100%, Protection On, protectors RecoveryPassword + Tpm.
  Fleet still "enforcing" at that moment.
- 13:47:41 Fleet queued `SystemDrivesRequireStartupAuthentication` (with the PIN nodes) for host 15.
- 13:48 **B-1 PASS** (`test-evidence/B/01-B1-registry.txt`): `HKLM\SOFTWARE\Policies\Microsoft\FVE` = UseAdvancedStartup 1,
  EnableBDEWithNoTPM 0, UseTPMKey 2, UseTPMPIN 2, UseTPMKeyPIN 2, UseTPM 2, MinimumPIN 6, UseEnhancedPin 1,
  DisallowStandardUserPINReset 0. PolicyManager: all four nodes from Fleet's provider (51DF321C-...).
- 13:47:52 Fleet: host 15 disk encryption **"action_required"**: "A required BitLocker startup PIN is not set. The disk is
  encrypted but a PIN must be configured for compliance." Command `SystemDrivesRequireStartupAuthentication` status 200.
- 13:48 **B-2: bug NOT reproduced on this VM.** Manage BitLocker for C: shows "Suspend protection", **"Change how drive is
  unlocked at startup"**, "Back up your recovery key", "Turn off BitLocker" (`test-evidence/B/03-B2-manage-bitlocker.png`) with
  Fleet's payload (all four startup methods at Allow). So on a desktop-class device that isn't Modern Standby, the sibling
  methods at Allow do not hide the option. This argues against the original theory as the customer's cause and toward the
  device class (Microsoft: HSTI / Modern Standby devices "won't be able to configure a Startup PIN using this CSP").
- 13:49 B-2 continued: "Change how drive is unlocked at startup" opens "Choose how to unlock your drive at startup" with
  **"Enter a PIN (recommended)"**, "Insert a USB flash drive", and the current "Let BitLocker automatically unlock my drive"
  (greyed). `test-evidence/B/04-B2-after-click-change.png`. No UAC prompt (the `lab` user is a local admin).
- 13:47 **B-3:** refetch requested 13:46:47 completed by 13:47:52 (`refetch_requested` false). No stall on this host.
- 13:52 **B-4 as expected** (`test-evidence/B/07-B4-my-device-3.png`, `08-B4-create-pin-click.png`; address bar masked, it
  holds the device token): My device banner "Disk encryption: Create a BitLocker PIN to protect your data if your device is lost
  or stolen. After, select Refetch to clear this banner." + "Create PIN". Agent 1.61.0. "Create PIN" opens the OLD instructions
  modal (Start menu > "Manage BitLocker" > "Change how the drive is unlocked at startup. If this option doesn't show up, wait a
  minute and relaunch Manage BitLocker." > "Enter a PIN (recommended)" > Refetch), not the 4.93 PIN form.
- 13:55 **PIN set by Adam through Manage BitLocker** ("Enter a PIN (recommended)", Fleet's own payload, all four methods at
  Allow): protectors now RecoveryPassword + **TpmPin** (TPM-only replaced); `manage-bde`: "TPM And PIN", Protection On. Manage
  BitLocker now also lists "Change PIN". `test-evidence/P/01-after-pin.txt`, `02-after-pin-dialog.png`.
- 13:57 Rebooting to check the pre-boot PIN prompt in UTM.
- 13:57-13:59 **Pre-boot (FAIL so far):** after the reboot the UTM window shows only the UEFI "Start boot option" frame with a
  text cursor; unchanged for 2+ min (`scratchpad` captures every 5 s; `test-evidence/P/03-now.png`). No BitLocker PIN or recovery
  screen visible. A test digit then Backspace (no Enter) changed nothing; serial console (`/dev/ttys001`) silent. First reboot
  since Fleet encrypted C:, so TPM-only unlock was never seen either. Note: the first VM build also froze on this same frame after
  its 0xED blue screen (it had been auto-encrypted then), so UTM may not show Windows Boot Manager's BitLocker screens at all.
- 14:01 **Pre-boot PIN in UTM: FAIL.** Adam typed the PIN blind in the UTM window and pressed Enter: nothing changed, Windows
  didn't start (guest agent down; Fleet: host offline, last seen 11:56:50 UTC). Trying a plain `ramfb` display to see the screen.
- 14:02 Display `ramfb` (instead of `virtio-ramfb`): UTM shows "Guest has not initialized the display (yet)." for 50+ s; the
  firmware never draws. `test-evidence/P/ramfb/`.
- 14:04 Display `virtio-gpu-pci`: firmware text visible, "BdsDxe: starting Boot0006 "Windows Boot Manager" from HD(1,GPT,...)
  /\EFI\Microsoft\Boot\bootmgfw.efi", then nothing for 30+ s; QEMU ~250% CPU (busy, not idle). `test-evidence/P/virtio-gpu/`.
- **Conclusion (pre-boot): this UTM 4.7.5 setup (Apple Silicon, arm64 EDK2, swtpm) cannot boot Windows once C: has a TPM-based
  BitLocker protector:** Windows Boot Manager starts and never shows the PIN (or recovery) screen with either display, and a
  blind PIN + Enter does nothing. Probably the boot manager stuck on the emulated TPM (Windows' `Get-Tpm` also failed); not
  proven. Same frozen frame as the first build after Windows auto-encrypted it. **The startup PIN can't be tested in this VM.**
- (Customer-requirements review: internal notes, not published here.)
- 14:12 Fleet never saw the PIN: last status for host 15 is "action_required" (13:47:52); no refetch ran between the PIN (13:55)
  and the reboot (13:57), and the host has been offline since. So Fleet's side of B (status -> Verified, `tpm_pin_set`) is NOT-RUN.
- 14:13 Adam: rebuild and test the customer's case (N-2). Old VM moved to `vm/broken-pin.utm` (28 GB; Mac now 29 GB free).
  Answer file adds standard user `labuser` (blank password); setup switches auto sign-in to `labuser` after setup.
- 14:15 VM #3 building. fleetd MSI **without Fleet Desktop** built: `out/no-desktop/fleet-osquery-arm64.msi`.
- 14:30 VM #3 setup done (no blue screen): guest tools installed, auto sign-in switched to `labuser`, C: Fully Decrypted.
- 14:35 VM #3 restarted with both CD drives empty; signed in as `labuser` (not in Administrators). fleetd 1.61.0 **without Fleet
  Desktop** installed (`test-evidence/N2/01-install.txt`).
- 14:37 It re-enrolled into the **same Fleet host record 15** (`last_enrolled_at` 12:37:12 UTC), not a new host.
  Reason: all three VMs report the same SMBIOS UUID (ends DD9CAE), so Fleet matches them to one host.
- 14:40:34 **S-4 (VM #3):** C: Used Space Only Encrypted, Protection On, protectors RecoveryPassword + Tpm. Fleet: "action_required"
  (PIN not set); Fleet queued its `SystemDrivesRequireStartupAuthentication` (PIN Allow) at 12:40:41 UTC.
- 14:42:23 **N-2:** profile C (PIN Required, other methods Disallowed) uploaded 14:40:48, **Verified** 14:42:23. Fleet's own command
  had landed first (UseTPMPIN 2 at 14:41:19); the profile overrode it: FVE = UseTPMPIN 1, UseTPM 0, UseTPMKey 0, UseTPMKeyPIN 0,
  MinimumPIN 6, UseEnhancedPin 1, DisallowStandardUserPINReset 0 (`test-evidence/N2/04-after-profile-C.txt`). Protectors unchanged
  (RecoveryPassword + **Tpm**), Protection On: Windows keeps the now-disallowed TPM-only protector; nothing forces a PIN.
  Fleet still "action_required"; no new Fleet BitLocker command after the profile (so far).
- 14:43 **N-2 (standard user, no Fleet Desktop, PIN Required by custom profile):** no prompt or notification appeared for
  `labuser`. Manage BitLocker shows "Change how drive is unlocked at startup" (UAC shield on every action;
  `test-evidence/N2/05-labuser-manage-bitlocker.png`). Clicking it opens **UAC: "BitLocker Drive Encryption Wizard ... To
  continue, enter an admin username and password."** (`06-labuser-click-change.png`). So a standard user can't add the PIN
  without admin credentials, and the Required policy doesn't push them to. This is the customer's case (R3 + R4): not met.
- 14:46:51 Fleet sent no BitLocker command after profile C (commands since enrollment: poll interval 12:39:13Z, Fleet's
  SystemDrivesRequireStartupAuthentication 12:40:50Z, profile install 12:42:20Z). Policy still UseTPMPIN 1, UseTPM 0; protectors
  RecoveryPassword + Tpm. Refetch requested 14:47 to make Fleet's PIN check run again.
- 14:48 After the refetch (detail_updated_at 12:48:11Z) Fleet still sent no BitLocker command; UseTPMPIN 1, UseTPM 0 held. So the
  custom PIN-Required profile **coexisted with Fleet's own disk encryption** (escrow + status kept) in this state. Caveat: only
  while a TPM boot protector exists; with none and UseTPM 0, `bitlocker_startup_policy_relax` would reset the dropdowns (code).
- 14:45 Admin step (does an admin's "Enter a PIN" work with PIN Required?) NOT-RUN: the UAC prompt closed before Adam could use it.
- 14:51 **N-2b (admin, PIN Required by profile C):** Adam approved UAC as `lab` (empty password) and used "Enter a PIN" ("Choose a
  PIN that's 6–20 characters long."; `test-evidence/N2/08-admin-pin-1.png`, dots only). **PIN set on the already encrypted drive:**
  protectors RecoveryPassword + **TpmPin** (TPM-only replaced; `11-after-admin-pin.txt`). Manage BitLocker now shows the banner
  "For your security, some settings are managed by your system administrator.", "Change PIN", and no longer "Change how drive is
  unlocked at startup" (no other method allowed) (`10-admin-pin-3.png`, `12-after-pin-now.png`). So with siblings Disallowed,
  Required (1) does NOT block adding a PIN on an encrypted drive (Victor's April "could not set a PIN at all" was probably a
  different setup; his screenshot wasn't read).
- 14:53:27 **Fleet: host 15 disk encryption "verified"** after a refetch (custom PIN-Required profile + Fleet's own encryption
  and escrow, PIN added by an admin). No reboot (the UTM pre-boot limit).
- 14:58 Adam: nothing gets closed or posted by Claude; drafts only; follow process. Handbook: Manager of CSA decides whether a
  customer-labelled request is fulfilled (product-design "Confirm and celebrate"); the CSM informs the customer and closes
  (customer-success "Communicate feedback on prioritized customer requests"). `ISSUE_UPDATE.md` rewritten as that proposal;
  `EVIDENCE.md` lists each test with its evidence.

## Side tests for fleetdm/fleet#27903 (full vs used-space encryption, all drives), 2026-10-15
Plan: `notes/27903-research.md`. Profiles E (`SystemDrivesEncryptionType` = 1) and F (`RequireDeviceEncryption` 1 +
`AllowWarningForOtherDiskEncryption` 0). Evidence: `test-evidence/27903/`.
- 15:13 **Pre-state** (`00-pre-state.txt`): VM #3 C: 62.89 GB, Used Space Only Encrypted, Protection On, protectors
  RecoveryPassword + TpmPin; 36.1 GB free in C:; one 64 GB NVMe disk (EFI, MSR, C:, Recovery), no data volume; C: can shrink to
  26.84 GB. Fleet 7: Windows disk encryption on, PIN required on, profile C attached.
- 15:16 **BLOCKED (Mac disk space):** `/System/Volumes/Data` has **5.7 GB** free (not 29 GB). The VM's qcow2 is 22 GB of a
  64 GB virtual disk. Full encryption (test 1) and `manage-bde -w` (test 2) write every free sector, so the qcow2 can grow by up
  to ~42 GB. Not started. Needs Adam to free space (e.g. delete `vm/broken-0xED.utm` 21 GB and `vm/broken-pin.utm` 28 GB).
- 15:16 **Microsoft doc (BitLocker CSP, 2025-11-06), relevant to test 3:** `AllowWarningForOtherDiskEncryption` = 0 "can only be
  set for Entra ID joined devices"; with it off, the OS key backs up to the user's Entra account, and a fixed data drive's key
  must back up to AD DS, Entra or OneDrive first ("Encryption waits until one of these three locations backs up successfully").
  `AllowStandardUserEncryption` (standard user signed in) is tied to silent mode. This lab host is not Entra joined.
- 15:20 Holding all VM-disk-writing steps until the starting session confirms space is freed (it is asking Adam; nothing deleted).
- 15:20 Evidence script `tests/27903-check.ps1` (read-only; protector types only). Run on the current C: (`01-pre-check.txt`):
  **`Get-BitLockerVolume` says `VolumeStatus FullyEncrypted` for this Used Space Only volume**, so only `manage-bde -status`
  ("Conversion Status") tells full from used-space. fleetd's log (`...\FleetDM\Orbit\Logs\orbit-osquery.log`, 59 lines since
  install 14:36) has no encryption-mode line for the 14:40 used-space encryption: fleetd logs one at INFO only when
  `OSEncryptionType` = 1.
- 16:28 Adam approved: deleted vm/broken-0xED.utm and vm/broken-pin.utm; Mac now 39 GB free (ISO clones shared blocks). For the 27903 tests.
- 16:29 Adam approved deleting `vm/broken-0xED.utm` and `vm/broken-pin.utm` (done by the starting session); Mac 39.4 GB free.
  Watchdog `test-evidence/27903/disk-watch.log` (every 20 s: Mac free space + qcow2 size; pauses BitLocker in the guest and
  stops below 10 GB).
- 16:30:10-16:30:23 **C: shrunk 62.89 -> 36.00 GB** (`Resize-Partition`, on the encrypted Used Space Only volume; Microsoft's
  doc covers shrinking BitLocker volumes) to cap qcow2 growth. C: 9.2 GB free, still Used Space Only Encrypted, Protection On,
  protectors unchanged; ~27 GB unallocated at the end of the disk (`02-shrink-c.txt`). Deviation from a customer setup: smaller C:.
- 16:30:41 **T2 (`manage-bde -w C:` on a Used Space Only C:, run as a Fleet script): PASS.** `fleetctl run-script` with
  `tests/27903-wipe-free-space.ps1` returned in ~20 s, exit 0 (`03-T2-fleet-script.txt`): `manage-bde -w` prints "Free space
  wiping is now in progress." and returns at once (exit 0); the wipe runs in the background ("Percentage Wiped: 2.3%" right
  after). No Fleet script timeout risk. Events (`05-T2-wipe-events.txt`): BitLocker Management 786 "free space wiping was
  started" 16:30:57; System BitLocker-Driver 24649 started 16:30:57, **24651 "Wiping of free space on volume C: completed."
  16:31:19**. After: still **"Used Space Only Encrypted"**, Protection On, same protectors (`04-T2-after-wipe.txt`,
  `06-T2-after-wipe.png`). So the wipe doesn't change the reported mode: proof of the wipe is event 24651, not manage-bde.
  qcow2 22.0 -> 32.1 GB in that 20 s (the wipe wrote the 9.2 GB of free space). Fleet: activity "ran_script" 14:31:10Z; host
  disk encryption still "verified" (Fleet doesn't report full vs used-space).
- 16:33:36 qcow2 back to 20.8 GB after the wipe (Mac 41.5 GB free): Windows' TRIM reaches the qcow2 (UTM discard), so the
  wipe's growth was temporary here.
- 16:33:51 Fleet 7: profile C deleted (API), Windows disk encryption **off**, PIN off. 16:34:08 the VM's
  `HKLM\SOFTWARE\Policies\Microsoft\FVE` key was gone (Fleet's removal command 14:34:09Z, status 200)
  (`07-after-remove-C.txt`).
- 16:34:39-16:35:41 `manage-bde -off C:`: Fully Decrypted, "Key Protectors: None Found", no FVE policy (`09-decrypted.txt`).
- 16:36:12 Profile E (`SystemDrivesEncryptionType` `<enabled/><data id="OSEncryptionTypeDropDown_Name" value="1"/>`) uploaded to
  fleet 7; Fleet "verified" by 16:36:29; VM: `FVE\OSEncryptionType` = 1 at 16:37:10 (`11-T1-profile-E-landed.txt`).
- 16:37:32 Fleet 7 Windows disk encryption **on** (PIN off); accepted with the custom BitLocker profile present. Refetch 16:37:40.
- **T1 (full encryption of C: via `SystemDrivesEncryptionType` = 1 with Fleet's disk encryption on): FAIL.** C: ended
  **"Used Space Only Encrypted"** (16:40:25), not "Fully Encrypted". fleetd log (`12-T1-fleetd-log.txt`), complete since 16:37:
  `16:38:58 INF OSEncryptionType registry policy requires full disk encryption, using full encryption mode` /
  `16:38:58 INF deleted orphaned OSEncryptionType registry policy value` /
  `16:38:59 ERR failed to encrypt the volume error="starting encryption: encrypt(C:): the encryption flags conflict with the
  current Group Policy settings (check HKLM\\SOFTWARE\\Policies\\Microsoft\\FVE)"`. Then, with nothing logged, fleetd retried
  at 16:39:30: BitLocker 778 "reverted to an unprotected state" (old protectors removed), new protectors, 768 "encryption was
  started ... XTS-AES 256", System 24660 "BitLocker encryption on write started" (not mode-specific: F:'s full encryption at 16:45 logged it too), 24667 finalization
  sweep completed 16:40:25 (`13-T1-events.txt`). The FVE key is now empty: fleetd deleted `OSEncryptionType` before the first
  attempt, so the retry saw no policy and used `EncryptDataOnly`.
  **Cause (code + Microsoft doc):** fleetd 1.61.0 maps `OSEncryptionType` = 1 to `EncryptDemandWipe` = `0x2`
  (`orbit/pkg/bitlocker/bitlocker_management_windows.go:38,459`). Microsoft's `Win32_EncryptableVolume.Encrypt` doc: `0x2` =
  "Perform on-demand wipe of the volume free space ... only allowed when volume is ... in an 'encrypted' state"; full mode is
  bit `0x1` **not set** (flags 0). So on a decrypted C: the call returns `E_INVALIDARG` (fleetd prints it as the "flags
  conflict with Group Policy" message), and the retry falls back to used-space because the value was already deleted.
- 16:41 **Fleet after refetch (`14-T1-fleet-host.txt`): disk encryption "verified", profile E "verified"**, while C: is Used
  Space Only. Fleet shows no sign that the requested full encryption didn't happen.
- 16:43:45 `OSEncryptionType` still absent from `FVE` 5 min after fleetd deleted it; Windows' PolicyManager still holds
  `SystemDrivesEncryptionType` (ProviderSet 1, Fleet's enrollment as winning provider); last PolicyManager event 814 "Set
  policy string ... OSEncryptionTypeDropDown_Name value=1" at 16:36:28. So the value does not come straight back (re-checked below).
- 16:44 F: created: 2 GB NTFS data partition in the space freed from C: (D: and E: are the empty CD drives)
  (`15-new-F-partition.txt`).
- 16:45 **Flag proof on F: (`tests/27903-flag-proof.ps1`, `16-flag-proof-F.txt`):** same WMI calls as fleetd (PrepareVolume
  `<default>`/software rc 0, ProtectKeyWithNumericalPassword rc 0), then **Encrypt(XTS-AES 256, flags `0x2`) rc `0x80070057`
  (E_INVALIDARG)**, volume still Fully Decrypted; **Encrypt(XTS-AES 256, flags `0`) rc 0 -> "Fully Encrypted"** 100% in ~2 s
  (24667 at 16:45:29). No FVE policy at all here, so the failure is the flag, not a policy conflict. fleetd would need flags
  `0` for full mode (and should delete `OSEncryptionType` only after a successful start, or not at all).
- 16:46:26 F: decrypted again (no protectors) to serve as an unencrypted fixed data drive for T3 (`17-F-decrypt.txt`).
- **T3 (second fixed drive + `RequireDeviceEncryption` 1 + `AllowWarningForOtherDiskEncryption` 0, Fleet's disk encryption
  on, host NOT Entra/AD/workplace joined, standard user `labuser` signed in): F: NOT encrypted (no silent encryption, no
  prompt).**
  - 16:46:50 profile F uploaded; Fleet "verified" by 16:47:17. VM: PolicyManager set both values without error (813 events at
    16:47:05-06; `AllowWarningForOtherDiskEncryption` = 0 accepted although Microsoft says 0 "can only be set for Entra ID joined
    devices"); MDM warning **2910 "BitLocker CSP: Fixed Drive not protected."** 16:47:06 (`19-T3-check-1.txt`).
  - Scheduled task `\Microsoft\Windows\BitLocker\BitLocker MDM policy Refresh` ran 16:47:06 and again (manual) 16:48:34:
    **result `0x80070032` (ERROR_NOT_SUPPORTED)**; F: Fully Decrypted; no BitLocker events; no prompt on screen
    (`20-T3-screen-1.png`, `21-T3-refresh-task.txt`). `dsregcmd`: AzureAdJoined NO, DomainJoined NO, WorkplaceJoined NO.
  - 16:49:04 variant: profile G (`AllowStandardUserEncryption` = 1) added; set at 16:49:36. The refresh task then returned
    **`0x00000000`**, but F: stayed Fully Decrypted for 5+ min (16:50-16:55 polls), no BitLocker events
    (`22-T3-with-G.txt`). Consistent with Microsoft: a fixed data drive's key must first back up to AD DS, Entra or OneDrive
    ("Encryption waits until one of these three locations backs up successfully"); this host has none.
  - No conflict with fleetd: C: unchanged (Used Space Only, RecoveryPassword + Tpm), no fleetd BitLocker log lines or errors
    since 16:40. Fleet: disk encryption "verified"; **profiles E, F, G all "verified"** while F: is unencrypted
    (`24-T3-fleet-host.txt`, `23-T3-control-panel.png`: "Windows (C:) BitLocker on", "Data27903 (F:) BitLocker off").
  - Not tested: an Entra-joined host (where Microsoft says silent mode works and keys go to Entra, not Fleet).
- 16:57:20 Cleanup after T3: profiles F and G deleted (Fleet's removal reset `RequireDeviceEncryption` 0,
  `AllowWarningForOtherDiskEncryption` 1, `AllowStandardUserEncryption` 0 by 16:58:08); fleet 7 disk encryption off; 17:02:32
  `manage-bde -off C:` -> Fully Decrypted, no protectors 17:03:39. Profile E kept.
- **W (workaround: full encryption by Fleet script before Fleet's disk encryption, then Fleet on): full mode PASS, escrow NOT
  shown.** 17:03:47 `fleetctl run-script tests/27903-encrypt-c-full.ps1` (`Enable-BitLocker -MountPoint C: -EncryptionMethod
  XtsAes256 -TpmProtector -SkipHardwareTest`, no `-UsedSpaceOnly`): exit 0, "Encryption in Progress" (`26-W-...txt`);
  **"Fully Encrypted" 17:05:38** (`27-W-fully-encrypted-before-fleet.txt`). 17:06:11 fleet 7 disk encryption on + refetch
  (Fleet detail update 15:06:47Z): **fleetd did nothing for 11 min** (no log lines; protectors stayed `Tpm` only) and **Fleet
  showed "verified" throughout** (`28-W-after-fleet-on-watch.txt`, `29-W-state.txt`). Cause (code, `server/service/orbit.go`
  1170-1175 at 4.93.0): Fleet asks fleetd to encrypt/escrow only if the host isn't encrypted, has no decryptable key, or reported
  an error. Host 15 still has the key escrowed at 16:39, whose RecoveryPassword protector was destroyed by the 17:02 decryption,
  and `bitlocker_key_protectors_verify` checks only for a TPM-family protector and a PIN, not for a recovery password. So
  **Fleet showed "verified" holding a recovery key that can't unlock C:** (C: has no numerical password protector).
  A host with no key in Fleet should take fleetd's other path (`notifications.go:795`: conversion status "fully encrypted" ->
  rotate and escrow a new recovery password); not tested (needs a host Fleet has never escrowed for).
- 17:17 `OSEncryptionType` still absent from `FVE` ~38 min after fleetd deleted it (16:38:58): the MDM did not restore it.
- 17:17:40 Restore a consistent lab state (valid escrowed key): profile E deleted (fleet 7 has no profiles); 17:18:16-17:19:21
  `manage-bde -off C:` -> Fully Decrypted; refetch. Fleet (detail 15:20:12Z): `disk_encryption_enabled` false, status label
  **"verifying"** for a decrypted C: (stale key still escrowed). fleetd didn't act: it waits `windowsMDMBitlockerCommandFrequency`
  = 1 h after its last BitLocker run (16:39:30; `orbit/cmd/orbit/orbit.go:1236`). 17:22:19 restarted the `Fleet osquery`
  service to reset that timer (`32-restore-restart-fleetd.txt`).
- 17:22:20-17:23:32 After the restart fleetd encrypted C: (used space, RecoveryPassword + Tpm) and escrowed; refetch 17:23:37;
  **Fleet "verified" at 15:24:55Z with the new key** (`31-restore-watch.txt`, `33-final-state.txt`).
- **End state (17:25):** C: 36 GB Used Space Only Encrypted, RecoveryPassword + Tpm, key escrowed in Fleet; F: 2 GB unencrypted
  data partition; no FVE policy. Fleet 7: Windows disk encryption on, **require_bitlocker_pin off** (YAML baseline: on), no
  profiles. VM still running, not rebooted. Mac free space never went below 29.3 GB (watchdog stopped).
- 17:38 **Policy check (Victor's "policy + script", Marko's Apr 27 version):** live query on host 15 (no PIN after the 27903 tests):
  `bitlocker_key_protectors` for C: = types 3 (recovery password) + 1 (TPM). Policy query
  `SELECT 1 FROM bitlocker_key_protectors WHERE drive_letter = 'C:' AND key_protector_type IN (4, 6);` returned no rows, so the
  host **fails** the policy, as it should (`test-evidence/policy/`). The passing case (TPM+PIN present) wasn't re-run live; Fleet's
  own PIN check uses the same table and showed Verified at 14:53 when the TpmPin protector existed.
- (Customer-requirements review: internal notes, not published here.)
- 17:44 **Clean-up (Adam approved):** VM `bitlocker-lab` stopped and its bundle deleted (31 GB; UTM's three leftover list entries
  disappeared on restart; other labs' VMs untouched). Fleet host 15 deleted from fleet 7 (fleet 7 now has no hosts; its escrowed
  recovery key went with it). GitOps repo pushed (114cbec..2ee4f88): `testing/bitlocker-pin-42318/` + README pointers; no apply
  ran. Mac: 61 GB free.
