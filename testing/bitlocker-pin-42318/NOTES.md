# Open items
- **Next host: a physical Modern Standby laptop** (ideally Lenovo, like customer-deebradel). Check `powercfg /a` ("Standby (S0
  Low Power Idle)") first, then: Fleet's payload (baseline) -> Manage BitLocker; then profile D (adds
  `SystemDrivesEnablePrebootInputProtectorsOnSlates`), then A. Pre-boot PIN on the real keyboard.
- VM `bitlocker-lab` no longer boots (C: has TPM And PIN; Windows Boot Manager never shows the PIN screen in UTM). To reuse it:
  boot the Windows ISO into recovery and unlock C: with the recovery key from Fleet (Adam types), or rebuild (`vm/build-vm.sh`).
- When fleetd 1.62 ships: test the 4.93 My device PIN form (needs Fleet's disk encryption on + Fleet Desktop).
- Fleet 7's YAML holds the baseline (disk encryption + PIN required). Host 15 is enrolled there and now offline.
- GitOps applies need the #54654 SCEP tunnel up (pid 92013 started 13:12).
- Started outside this lab today: #54654 `cloudflared` tunnel and that lab's Docker `pingfederate`/`step-ca`. Stop only if Adam says so.

# Not tested / caveats
- Fleet 4.93.0's My device PIN form + fleetd WMI flow: needs fleetd from `main` (capability `windows_bitlocker_pin`); stable and
  edge are 1.61.0 on 2026-10-15. Testing it would need an orbit build from `main`.
- Custom-profile route: with the fleet's disk encryption off, Fleet does not escrow the recovery key or report disk encryption
  status. Microsoft's CSP doc says the CSP can't set a PIN on HSTI / Modern Standby devices.
- VM vs. the customer: arm64, QEMU firmware, not a physical laptop (S-1b records how Windows classifies it).
- First VM build's blue screen (0xED) cause is unconfirmed. It froze on the same firmware frame as the encrypted 2nd build, so
  the likelier story is Windows auto-encrypting it with the TPM and the boot manager then failing in UTM.
- UTM limitation found: Windows on arm64 in UTM 4.7.5 can't boot with a TPM And PIN protector (boot manager never draws).
  TPM-only reboot was never observed either.

# Reference
- Fleet code: `server/mdm/microsoft/bitlocker_csp.go`, `server/service/osquery_utils/queries.go` (`tpm_pin_config_verify`,
  `bitlocker_startup_policy_relax`, `bitlocker_key_protectors_verify`). Repo `/Users/adam/Documents/GitHub/fleet` (read-only);
  use tag `fleet-v4.93.0` to match the lab.
- Side research (Adam, 2026-10-15): fleetdm/fleet#27903 used-space vs full encryption and all drives. `notes/27903-research.md`, draft reply `notes/27903-draft-comment.md` (Adam posts). **Tested** 15:13-17:25 (RESULTS.md "Side tests for #27903"): `SystemDrivesEncryptionType`=1 FAILS with fleetd 1.61.0 (flag bug, ends used-space); `manage-bde -w` as a Fleet script PASSES; `RequireDeviceEncryption` didn't encrypt a data drive on this non-Entra host. Candidate bugs for Adam: fleetd Encrypt flag `0x2`; Fleet "verified" with a stale recovery key.
- VM changed by the 27903 tests: C: shrunk to 36 GB, 2 GB data partition F: (unencrypted). Fleet 7: PIN required **off** (YAML baseline: on).
