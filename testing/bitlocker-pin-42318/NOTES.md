# Open items (2026-10-15, 22:40)
- **Follow-ups on this VM (optional):** F-1 full standard-user PIN change (Adam types PINs); F-2 Fleet script with a PIN IT knows
  (Fleet secret variable, global: Adam's OK); F-3 Fleet policy for users locked out of PIN changes; F-4 why the threshold 3 didn't
  apply. See `TEST_PLAN.md` "Follow-ups (F)".
- **Next host: a physical Modern Standby laptop** (ideally Lenovo, like customer-deebradel). Check `powercfg /a` ("Standby (S0
  Low Power Idle)") first, then: Fleet's payload (baseline) -> Manage BitLocker; then profile D (adds
  `SystemDrivesEnablePrebootInputProtectorsOnSlates`), then A. Pre-boot PIN on a real keyboard (the VM now shows it; see below).
- VM `bitlocker-lab` (host 16) is at the **BitLocker recovery screen** (23:2x, after the pre-boot lockout test; PIN random/unknown).
  To use it again Adam types the recovery key from Fleet (host 16 > Actions > Show disk encryption key). Its TPM keeps the legacy lockout values
  until cleared. labuser's in-Windows PIN changes are disabled after the L-2 test (expect it to clear after ~8 h).
- Fleet 7 has profiles C and H beyond its YAML; a GitOps apply removes them.
- When fleetd 1.62 ships: test the 4.93 My device PIN form (needs Fleet's disk encryption on + Fleet Desktop).
- GitOps applies need the #54654 SCEP tunnel up, and currently also the empty iOS enroll secret set (LUKS session note).
- Started outside this lab today: #54654 `cloudflared` tunnel and that lab's Docker `pingfederate`/`step-ca`. Stop only if Adam says so.

# Not tested / caveats
- Fleet 4.93.0's My device PIN form + fleetd WMI flow: needs fleetd from `main` (capability `windows_bitlocker_pin`); stable and
  edge are 1.61.0 on 2026-10-15. Testing it would need an orbit build from `main`.
- Custom-profile route: with the fleet's disk encryption off, Fleet does not escrow the recovery key or report disk encryption
  status. Microsoft's CSP doc says the CSP can't set a PIN on HSTI / Modern Standby devices.
- VM vs. the customer: arm64, QEMU firmware, not a physical laptop (S-1b records how Windows classifies it).
- First VM build's blue screen (0xED) cause is unconfirmed. It froze on the same firmware frame as the encrypted 2nd build, so
  the likelier story is Windows auto-encrypting it with the TPM and the boot manager then failing in UTM.
- Lockout (L-1/L-2): the standard-user thresholds of 3 didn't stop PIN changes at 3; it stopped after 4–5 (matches Windows'
  default of 4). Unverified whether the value needs a TBS restart or reboot. Pre-boot lockout tested 23:2x: 6th wrong PIN in one boot -> recovery screen (TPM limit 32 not reached).
- D-1: a successful standard-user PIN change wasn't completed (no known PIN); only the dialog, rejection and lockout were seen.
- Corrected 23:15: UTM 4.7.5 arm64 DOES show the pre-boot PIN screen. The earlier hang (13:57–14:10) is unexplained: since then
  Windows installed updates and `displaybootmenu` was turned on; the ISOs are still attached as USB drives.
  TPM-only reboot was never observed either.

# Reference
- Fleet code: `server/mdm/microsoft/bitlocker_csp.go`, `server/service/osquery_utils/queries.go` (`tpm_pin_config_verify`,
  `bitlocker_startup_policy_relax`, `bitlocker_key_protectors_verify`). Repo `/Users/adam/Documents/GitHub/fleet` (read-only);
  use tag `fleet-v4.93.0` to match the lab.
- Side research (Adam, 2026-10-15): fleetdm/fleet#27903 used-space vs full encryption and all drives. `notes/27903-research.md`, draft reply `notes/27903-draft-comment.md` (Adam posts). **Tested** 15:13-17:25 (RESULTS.md "Side tests for #27903"): `SystemDrivesEncryptionType`=1 FAILS with fleetd 1.61.0 (flag bug, ends used-space); `manage-bde -w` as a Fleet script PASSES; `RequireDeviceEncryption` didn't encrypt a data drive on this non-Entra host. Candidate bugs for Adam: fleetd Encrypt flag `0x2`; Fleet "verified" with a stale recovery key.
- VM changed by the 27903 tests: C: shrunk to 36 GB, 2 GB data partition F: (unencrypted). Fleet 7: PIN required **off** (YAML baseline: on).
