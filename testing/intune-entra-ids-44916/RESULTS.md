# Results: Intune and Entra device IDs on Windows hosts

## R-0: Source research (2026-11-09): INFO
- **Steps:** Read the issue and fleetdm/fleet#43723 with comments. Read Fleet code at `fleet-v4.93.1`. Searched Microsoft docs and community scripts for where each ID is stored.
- **Actual:** Intune ID: `EntDMID` under `Enrollments\<guid>\DMClient\MS DM Server`, readable by osquery. Entra ID: subject of the `MS-Organization-Access` device certificate, found through the thumbprint-named `JoinInfo` subkey. No `DeviceId` registry value exists. Details and sources in [NOTES.md](NOTES.md).
- **Finding:** The issue's Entra registry path is wrong. Fleet already collects the Entra ID on Windows for conditional access, but doesn't expose it on the host API.

## T-1 to T-3 (not run): NOT-RUN
- Need a lab Windows VM and a lab `fleetctl` context. See [HANDOFF.md](HANDOFF.md).

## T-4, T-5: BLOCKED
- No Entra or Intune tenant in the lab.
