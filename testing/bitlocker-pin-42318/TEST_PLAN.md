# Test plan: BitLocker PIN with a custom disk encryption profile (fleetdm/fleet#42318)

Question: with `mdm.enable_custom_disk_encryption` on, does a custom BitLocker profile let an end user add a startup PIN in
Manage BitLocker on an **already encrypted** Windows 11 Pro + TPM 2.0 host, with PIN at Allow (2)?

Lab: Fleet 4.93.0 `https://fleet.mpc.ad`, test fleet **7 "Windows BitLocker Lab"**, host UTM VM **`bitlocker-lab`**
(details in `CLAUDE.md` "Lab as built").

## What the customer needs (`notes/customer-ask.md`)
Enforced PIN (6 digits, lockout after 3 attempts) **without Fleet Desktop**, for **non-admin** users; their VM offered
**only USB** as a startup option. Today's tests (admin, Fleet Desktop, optional PIN) don't cover that. Next tests:
N-1 reproduce "only USB" on their device type, then profile D; N-2 profile C (Required) as a standard user without Fleet
Desktop + a fleetd script path; N-3 the 3-attempt lockout setting.

## Status (2026-10-15 14:10)
S-1 PASS (2nd build), S-1b recorded (not Modern Standby), S-2 PASS, S-3 PASS, S-4 PASS after detaching the ISOs.
B-1 PASS, **B-2 bug NOT reproduced** (PIN option shown and PIN added with Fleet's payload), B-3 no stall, B-4 old instructions.
Pre-boot PIN (T step 5): failed earlier in the day (VM hung at Windows Boot Manager); **works since 23:15** (PIN screen, wrong-PIN
message, recovery after the 6th wrong PIN). See RESULTS "Getting around the hardware".
T-A to T-D NOT-RUN: uninformative on this host (baseline already works) and the VM no longer boots. Next host: a physical
Modern Standby laptop. Details in RESULTS.md.

## Setup (S)
| ID | Step | Pass when |
|---|---|---|
| S-1 | Host: UTM VM `bitlocker-lab`, Windows 11 Pro 26H2 (26300) arm64, UEFI, TPM 2.0, built by `vm/build-vm.sh` (unattended) | Boots to the `lab` desktop; `tests/host-facts.ps1` shows TpmPresent/TpmReady and the build |
| S-1b | Is the VM like the customer's laptops? `tests/host-facts.ps1`: `powercfg /a` (Modern Standby = "S0 Low Power Idle"), PCSystemType, chassis, keyboards, WinRE | Recorded. If Fleet's own payload already shows "Change how drive is unlocked" here (B-2), the VM does not reproduce the bug: say so |
| S-2 | Fleet 7 "Windows BitLocker Lab" (GitOps `fleets/windows-bitlocker-lab.yml`); host enrolled with `out/fleet-osquery-arm64.msi`, Windows MDM on | Host in fleet 7, MDM "On" |
| S-3 | Render: 4.93.0 + `FLEET_MDM_ENABLE_CUSTOM_DISK_ENCRYPTION=true` (Adam) | **PASS 12:53**: profile A upload to fleet 7 returned a `profile_uuid` (then deleted) |
| S-4 | C: encrypted by Fleet (fleet 7 baseline: disk encryption on) with a TPM protector, key escrowed | `manage-bde -status C:` Fully Encrypted, protector TPM; Fleet disk encryption "Verified" |

## Baseline (B): Fleet's built-in toggle, to reproduce (fleet 7 as declared in its YAML)
| ID | Step | Expected (the bug) |
|---|---|---|
| B-1 | Fleet disk encryption on + "Require BitLocker PIN" | FVE registry: `UseAdvancedStartup=1`, `EnableBDEWithNoTPM=0`, `UseTPM=2`, `UseTPMPIN=2`, `UseTPMKey=2`, `UseTPMKeyPIN=2`, `MinimumPIN=6`, `UseEnhancedPin=1`, `DisallowStandardUserPINReset=0` |
| B-2 | Open Control Panel > BitLocker Drive Encryption (Manage BitLocker) | No "Change how drive is unlocked at startup" / "Enter a PIN" |
| B-3 | Refetch the host a few times | Note whether refetch stalls (the issue says physical hosts stop refetching) |
| B-4 | My device page and Fleet Desktop | Old "Manage BitLocker" instructions, no PIN form: fleetd 1.61.0 has no `windows_bitlocker_pin` capability (CLAUDE.md) |

## Theory (T): custom profiles, Fleet's disk encryption off on fleet 7
First turn fleet 7's disk encryption off (`fleetctl api ... /api/v1/fleet/disk_encryption`, see CLAUDE.md). Its YAML still says
on, so **no GitOps apply during the T tests** (or change the YAML first). Fleet doesn't decrypt C: when the setting goes off.
Profiles in `profiles/`. A–C also set minimum PIN length 6, enhanced PIN on, standard users can change PIN (what Fleet sends).
| ID | Profile | Dropdowns (TPM+key / PIN / TPM+PIN+key / TPM) | Expected if the theory holds |
|---|---|---|---|
| T-A | A - PIN allowed, USB key methods disallowed | 0 / 2 / 0 / 2 | "Change how drive is unlocked at startup" appears; "Enter a PIN" works |
| T-B | B - PIN only method allowed | 0 / 2 / 0 / 0 | Same, if TPM-only must be off. With Fleet's encryption on, `bitlocker_startup_policy_relax` would undo this (`UseTPM`=0) |
| T-C | C - PIN required, others disallowed | 0 / 1 / 0 / 0 | Microsoft's classic setup, for comparison with Victor's April error |
| T-D | D - Fleet's payload plus `SystemDrivesEnablePrebootInputProtectorsOnSlates` enabled | 2 / 2 / 2 / 2 | Second candidate (Microsoft CSP docs, 2025-11-06): without this node, PIN options "might not be available" on devices Windows treats as having no pre-boot input. If D passes and A fails, the fix is one extra node in Fleet's payload |

For each: remove the previous profile first, wait for the new one to show **Verified** in Fleet, then check:
1. `tools/win-run.sh bitlocker-lab - < tests/check.ps1` (FVE policy values, MDM PolicyManager values, `manage-bde -status`).
2. Manage BitLocker: is "Change how drive is unlocked at startup" there? Window-only screenshot.
3. Add the PIN: through the UI (Adam types it), else `manage-bde -protectors -add C: -TPMAndPIN` in the VM window (prompts;
   Adam types). Record any error text exactly.
4. `tests/check.ps1` again: a "TpmPin" protector. **Never** run `manage-bde -protectors -get` (it prints the recovery password).
5. Reboot: the pre-boot PIN prompt appears in the UTM window and Adam's PIN unlocks it.
6. Fleet: host disk encryption status, `tpm_pin_set`, refetch still works.

## Done when
A profile passes steps 1 to 6, or 15:00 arrives. Either way: `RESULTS.md`, then `ISSUE_UPDATE.md` drafted for Adam to post.

## Follow-ups (F), not run yet (added 2026-10-15 22:40)
Same VM and host 16; nothing here needs a reboot. Evidence goes in `test-evidence/follow-up/` with VM and Fleet UI screenshots.
| ID | What | How | Needs | Pass when |
|---|---|---|---|---|
| F-1 | Standard user completes a PIN change | As `lab`: "Reset a forgotten PIN" -> Adam types a known PIN. As `labuser`: "Change PIN", Adam types old + new. Then `tests/check.ps1`, Fleet refetch | Adam at the keyboard; L-2 block expired (~8 h after 22:22) | Change succeeds with no UAC; protector still TpmPin; Fleet disk encryption still Verified, policy 588 passes |
| F-2 | Fleet script sets a PIN IT knows | Variant of `tests/add-pin-random.ps1` reading `$FLEET_SECRET_BITLOCKER_PIN` (Fleet custom variable); run on host 16 | Adam's OK (Fleet secrets are instance-wide), Adam enters the value | Script exit 0, PIN never in output or activity; Fleet Verified; F-1 works with that PIN |
| F-3 | Fleet flags users locked out of PIN changes | Policy/query on `windows_eventlog` for channel `Microsoft-Windows-BitLocker/BitLocker Management`, event 790 (check the table exists in fleetd 1.61.0 first) | Nothing | Host 16 shows the 22:2x failures; policy fails on host 16 |
| F-4 | Why the standard-user threshold 3 didn't apply | `Restart-Service tbs`, wait for the L-2 block to expire, retry wrong old PINs as labuser | Nothing (low value) | Block after 3 (then the doc can say "after a restart") or still 4–5 (then the setting doesn't affect this dialog) |

