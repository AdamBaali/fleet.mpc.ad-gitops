# Results: Intune and Entra device IDs on Windows hosts

## R-0: Source research (2026-11-09): INFO
- **Steps:** Read the issue and fleetdm/fleet#43723 with comments. Read Fleet code at `fleet-v4.93.1`. Searched Microsoft docs and community scripts for where each ID is stored.
- **Actual:** Intune ID: `EntDMID` under `Enrollments\<guid>\DMClient\MS DM Server`, readable by osquery. Entra ID: subject of the `MS-Organization-Access` device certificate, found through the thumbprint-named `JoinInfo` subkey. No `DeviceId` registry value exists. Details and sources in [NOTES.md](NOTES.md).
- **Finding:** The issue's Entra registry path is wrong. Fleet already collects the Entra ID on Windows for conditional access, but doesn't expose it on the host API.

## T-0: Lab VM baseline (2026-11-09): INFO
- **Steps:** New QEMU VM `ids1` from the reset lab's base disk (Windows 11 Pro 26300, arm64). Installed osquery 5.24.1 from the official x64 MSI; its SHA-256 matches the GitHub release digest.
- **Actual:** No `JoinInfo` subkeys and no Entra certificates. 31 built-in `Enrollments` subkeys, none with `MS DM Server`.
- **Evidence:** `test-evidence/lab/T-0-baseline-and-osquery-version/`

## T-1: Query logic on faked data (2026-11-09): PASS
- **Steps:** `scripts/fake-ids.ps1 setup` writes one Intune enrollment and one Entra join (CA with the real multi-valued issuer, leaf `CN=<GUID>`, `JoinInfo\<thumbprint>`). Ran both files in `queries/` with osqueryi.
- **Expected:** Each query returns the faked ID.
- **Actual:** Both match character for character. osquery on Windows renders the leaf's `subject` and `common_name` as the bare GUID, and the issuer as `net + windows + MS-Organization-Access + 82dbaca4-...`, which Fleet's `LIKE` matches.
- **Evidence:** `test-evidence/lab/T-1-query-logic-on-faked-data/`
- **Finding:** `common_name` and `subject` give the same value for this certificate. Keep `common_name`: it stays the bare GUID if a real certificate has more subject fields. Confirm in T-4.

## T-2: Negative controls (2026-11-09): PASS
| Case | Change | Intune rows | Entra rows | Result |
| --- | --- | --- | --- | --- |
| T-2a | No fakes | 0 | 0 | PASS |
| T-2b | `JoinInfo` subkey, certificate deleted | 1 | 0 | PASS |
| T-2c | Subkey and certificate from another issuer | 0 | 0 | PASS |
| T-2d | Second, older Intune enrollment | 2, each with its key | 1 | PASS |
| T-2e | Second, older Entra join with its own certificate | 1 | 1, the newer ID | PASS |
- **Evidence:** `test-evidence/lab/T-2*/`
- **Finding:** T-2d shows why the report must not use `LIMIT 1` on the Intune side: two enrollments come back and only the key tells them apart. The lab can't show which one Windows keeps current. That needs T-5.

## T-3: Stored report and API: NOT-RUN
- `fleets/device-ids-lab.yml` and `lib/windows/reports/device-ids.reports.yml` are ready. The lab dry run passes (`fleetctl gitops --dry-run`, 2026-11-09). Needs the enroll secret in GitHub and a merge to `main`.

## T-4, T-5: BLOCKED
- No Entra or Intune tenant in the lab.
