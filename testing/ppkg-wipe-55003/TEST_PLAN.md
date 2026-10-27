# Test plan: reset a Windows host for a new user (fleetdm/fleet#55003)

Structure follows Fleet's story test plan (core flow, edge cases, then the checks that apply) and the
[design and QA considerations](https://github.com/fleetdm/fleet/blob/main/docs/Contributing/guides/ui/design-qa-considerations.md).
Results: [RESULTS.md](RESULTS.md).


## User story

As an IT admin, I want to reset a Windows host for a new user from Fleet, so it comes back to Windows setup, enrolls in
the same fleet again, and is ready for the next person, without reimaging it and without Microsoft Autopilot.

Mechanism under test: Fleet's provisioning package (the guide's package with fleetd) is on the host, either from setup
or staged later by Fleet in `C:\Recovery\Customizations`. Fleet sends `doWipePersistProvisionedData` (or
`doWipeCloudPersistProvisionedData`) as a custom MDM command. Windows wipes the user and re-applies the package, which
reinstalls fleetd.

A reset test passes only with screenshots of every screen the end user sees, the Fleet host page, and command or API output
for every state claim.


## Lab

- Fleet 4.93.0, fleet 10 "Windows Reset Lab" with end user authentication on. Mock SAML IdP ([IDP_SETUP.md](IDP_SETUP.md))
  with two test users.
- Windows 11 Pro 26H2 (26300.9457) arm64 VMs on Homebrew QEMU, one generalized clone of a golden image per test
  (`testing/_framework/vm/`). Each VM keeps its own SMBIOS UUID and serial, as hardware does.
- Two fleetd builds: MSI-B with `--bypass-end-user-auth`, MSI-N without. Each goes in a package built with ICD.exe with
  the guide's settings (PKG-B, PKG-N). The package is opened at the region screen.


## Setup

| ID | Check | Pass when |
|---|---|---|
| S-0 | Record Fleet version, the bypass setting, and which fleets require end user authentication | Recorded |
| S-2 | IdP configured in Fleet; only fleet 10 requires end user authentication | Recorded |
| S-3 | Golden VM at the region screen, network up, reaches Fleet and the IdP | Screens and output |
| S-3b | Windows Recovery Environment on, SMBIOS identity recorded | `reagentc` and SMBIOS output |
| S-4 | Builder VM with ICD.exe (ADK) | ICD.exe installed |
| S-5 | MSI-B and MSI-N built for arm64 | Only MSI-B carries the bypass property |
| S-6 | PKG-B and PKG-N built with the guide's settings | Two packages |
| S-7 | One USB image per package | Two images |


## Enrollment

| ID | Steps | Pass when |
|---|---|---|
| E-1b | Open PKG-B at the region screen on a fresh host | Enrolls during setup with no prompt; MDM On before any user |
| E-2 | Open PKG-N at the region screen | Fleet blocks enrollment until the IdP sign-in; host enrolls with the IdP user |
| E-3 | Look for the package on disk after setup | Location and permissions recorded |


## Core flow

Each test starts from a fresh generalized clone. "Host kept" means the host stays in Fleet through the reset.

| ID | Preconditions | Steps | Pass when |
|---|---|---|---|
| L-3 | Generalized VM, no Fleet | Call `doWipePersistProvisionedData` locally through the MDM WMI bridge | Reset completes and Windows boots to the region screen |
| C-1 | PKG-B at setup, user `lab1`, MDM On | Send `doWipePersistProvisionedData` with `fleetctl mdm run-command`; watch the reset and Fleet | fleetd running at the region screen; same Fleet host ID, newer `last_enrolled_at`; MDM On; no prompt; `lab1` gone |
| C-2 | PKG-N at setup, signed in as `eua-user-1`, MDM On | As C-1 | As C-1; record which IdP user Fleet shows |
| C-3 | As C-2 | As C-1, then delete the host once the device acknowledges the command; sign in as `eua-user-2` | New host with only `eua-user-2`; MDM On; every screen captured |
| C-4 | Host enrolled with MSI-B only, MDM On | Fleet script `scripts/stage-ppkg.ps1` stages the package in `C:\Recovery\Customizations`; wipe as C-1 | As C-1 |
| C-5 | As C-1 | Wipe with `doWipeCloudPersistProvisionedData` | As C-1; record download time |


## Edge cases

| ID | Case | Steps | Pass when |
|---|---|---|---|
| X-1 | Second reset of the same host | Run the reset again on a reset host | As C-1 |
| X-2 | Host off when the wipe is sent | Stop the VM, send the wipe, start the VM | Command runs at the next check-in, then as C-1 |
| X-3 | Enroll secret changed after the package was built | Replace fleet 10's secret through the API, reset, then restore it | Outcome recorded |
| X-4 | Host moved to another fleet before the reset | Move the host to No team, reset | Fleet the host lands in recorded |
| X-5 | Package with an older fleetd | Build the package with fleetd 1.58.0, reset | Versions before and after recorded |
| X-6 | End user authentication off on the fleet | Turn it off, reset a PKG-N host, delete the host after acknowledgment | Enrolls with no prompt |
| X-7 | No package left | Remove the kept package with a Fleet script, reset | No fleetd at the region screen; host never checks in |
| X-8 | BitLocker on before the reset | Turn on Fleet disk encryption, reset | Outcome recorded |


## UI, API and permissions

| ID | Check | Pass when |
|---|---|---|
| U-1 | Host page during the reset | Captured |
| U-2 | Host page after re-enrollment | Captured |
| U-3 | Activity feed after a reset | Captured with timestamps |
| U-4 | Built-in Wipe status versus the custom command | Recorded for the design |
| A-3 | `POST /api/v1/fleet/hosts/:id/wipe` with the reprovision types | Response recorded |
| P-1 | Which roles can send the wipe and run the staging script | Recorded per role |


## Out of scope

Autopilot, Entra join, `doAutomaticRedeployment`, Windows 10, Wi-Fi-only devices, and packages built in the
Configuration Designer GUI.
