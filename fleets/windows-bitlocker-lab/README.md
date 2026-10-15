# Windows BitLocker Lab

Fleet used to test whether a custom BitLocker profile lets Windows users add a startup PIN
([fleetdm/fleet#42318](https://github.com/fleetdm/fleet/issues/42318)). Owner: Adam Baali. Fleet id 7.

- **Config:** `../windows-bitlocker-lab.yml`. It holds the baseline: Fleet's own Windows disk encryption on and a BitLocker PIN
  required. During the custom-profile tests the lab turns disk encryption off and uploads profiles by API, so a GitOps apply in
  that window puts the baseline back.
- **Server option:** custom BitLocker profiles need `FLEET_MDM_ENABLE_CUSTOM_DISK_ENCRYPTION=true` on the Fleet server (Render),
  set on 2026-10-15. It isn't a GitOps setting.
- **Enroll secret:** `FLEET_WINDOWS_BITLOCKER_LAB_ENROLL_SECRET` (repository secret, passed in `workflow.yml`).
- **Host:** a Windows 11 Pro 26H2 arm64 VM with TPM 2.0 in UTM on Adam's Mac.
- **Tests, results and the profiles under test:** in the local lab folder `fleet-42318-lab` (not in this repo yet).
