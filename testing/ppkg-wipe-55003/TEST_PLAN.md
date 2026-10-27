# Test plan v2: Windows "reset for a new user" (reprovision) (fleetdm/fleet#55003)

Owner: Adam · v2 written 2026-10-26 after the first run ([TEST_PLAN-v1.md](TEST_PLAN-v1.md), [RESULTS.md](RESULTS.md)).
Structure follows Fleet's story test plan (Core flow, Edge cases, then the checks that apply) and the
[design / QA considerations](https://github.com/fleetdm/fleet/blob/main/docs/Contributing/guides/ui/design-qa-considerations.md) list.


## User story

As an IT admin, I want to reset a Windows host for a new user from Fleet, so it comes back to Windows setup, enrolls in
the same fleet again, and is ready for the next person, without reimaging it and without Microsoft Autopilot.

Mechanism under test: Fleet's provisioning package (the guide's ppkg with fleetd) is on the host, either from setup or
staged later by Fleet in `C:\Recovery\Customizations`. Fleet sends `doWipePersistProvisionedData` (or
`doWipeCloudPersistProvisionedData`). Windows wipes the user and re-applies the package, which reinstalls fleetd.

A test passes only with: VM window screenshots of every screen the end user sees, the Fleet host page (details and
activity) before, during, and after, and command or API output for every state claim.


## Already proven (v1)

| What | Test |
|---|---|
| Bypass build enrolls during Windows setup with no prompt; MDM On before any user | E-1, E-1b |
| No-bypass build: Fleet blocks until IdP sign-in; Edge opens on the 26H2 setup screen; host enrolls with the IdP user | E-2 |
| `doWipePersistProvisionedData` wipes the user and keeps the package in `ProgramData\Microsoft\Provisioning` | W-1b |
| A Fleet script stages the package in `C:\Recovery\Customizations`; the reset keeps and processes it | W-6 |
| Not proven: anything after the reset, because the reset Windows never booted in the lab | W-1b, W-6 |


## Phase 0: lab readiness (blocks everything below)

Two lab faults stopped v1. Fix them first, each with its own pass rule. Don't start Phase 1 until L-3 passes. VMs run
headless on Homebrew QEMU (`tools/qemu-boot.sh`), and every reset runs with `tools/qemu-watch.sh` to keep the screens.

| ID | Problem | Hypothesis | Steps | Pass when |
|---|---|---|---|---|
| L-1 | Clones share a Windows MDM hardware ID, so a second clone took over the first one's MDM record in Fleet (v1 W-1) | Clones of an image that already ran specialize share machine identity. Sysprep `/generalize` gives each clone its own | Generalize the golden image (after L-2), make two clones, enroll both | Fleet shows both hosts with MDM On and `connected_to_fleet` true at the same time |
| L-2 | First boot after a re-specialize hangs at "Start boot option", then 0xc0000001 (v1 reset and generalize) | UTM 4.7.5's QEMU/edk2 (utmapp/UTM#7648 and cold boots too). Power cycling didn't help (L-2, L-2A) | Run the same disk on Homebrew QEMU 11.1.2 and edk2 with `tools/qemu-boot.sh`, generalize, reboot | PASS 2026-10-27: boots to the region screen in about a minute (L-2C). All VMs move to Homebrew QEMU (NOTES, "Lab fix") |
| L-3 | Proof that resets work in the lab | Same fix covers push-button reset | On a generalized VM with no Fleet at all: call `doWipePersistProvisionedData` locally through the MDM WMI bridge (`payloads/local/wipe-persist-local.ps1`) | PASS 2026-10-27: reset done and back at the region screen in 11.5 minutes (test-evidence/lab/L-3) |

Lab rules from v1 that stay: detach the USB drive after the package applies; capture windows by ID (off-screen works);
three-digit screenshot numbers; one host lineage at a time until L-1 passes.


## Phase 1: Core flow

Fleet 10 "Windows Reset Lab" requires end user authentication. Each test starts from a fresh generalized clone. "Host
kept" means the host stays in Fleet through the reset.

| ID | Preconditions | Steps | Expected | Pass when |
|---|---|---|---|---|
| C-1 | PKG-B (bypass) applied at setup, user `lab1` signed in, MDM On | 1. Fleet page and activity captured. 2. `fleetctl mdm run-command` with `doWipePersistProvisionedData`. 3. Watch the reset to the region screen. 4. Watch Fleet. 5. Finish setup as `lab2` | Device wiped, back at the region screen with fleetd running, host checks in during setup with no prompt, MDM On again | fleetd service Running at the region screen; same Fleet host ID with a newer `last_enrolled_at`; MDM On and `connected_to_fleet` true; no prompt on any screen; `lab1` profile gone |
| C-2 | PKG-N (no bypass) applied at setup, signed in to the IdP as `eua-user-1`, MDM On | Same as C-1 | Fleet treats it as a re-enroll of a known host (`HostPreviouslyOrbitEnrolled`) and lets it in without the IdP | Same as C-1, and record which IdP user Fleet shows. If Fleet still shows `eua-user-1`, that's the repurposing finding |
| C-3 | As C-2 | 1–2 as C-1. 3. After the device acknowledges the command, delete the host in Fleet. 4. At the setup screen, sign in as `eua-user-2` | Fleet blocks until sign-in; Edge shows Fleet's sign-in page on the setup screen; host enrolls with `eua-user-2` | New host record with only `eua-user-2` under end users; MDM On. Screens of every step for the user docs |
| C-4 | Host enrolled with MSI-B only (no package at setup), MDM On | 1. Push the package to `C:\Windows\Temp` (lab shortcut). 2. Fleet script `scripts/stage-ppkg.ps1` stages it in `C:\Recovery\Customizations`. 3. Wipe as C-1 | Same as C-1. This is the brownfield path (Omnissa pattern, NOTES D-7) | Same as C-1 |
| C-5 | As C-1 | Wipe with `doWipeCloudPersistProvisionedData` | Downloads a fresh image, then as C-1 | Same as C-1; record download time and disk space used |


## Phase 2: Edge cases

From the QA considerations list: wiped host, deleted host, offline host, host transferred between fleets, enroll secret
changes, fleetd versions, end user authentication on and off, and repeat actions.

| ID | Case | Steps | Expected | Pass when |
|---|---|---|---|---|
| X-1 | Second reset of the same host | Run C-1 again on C-1's host | Same result again | Same as C-1 |
| X-2 | Host offline when the wipe is sent | Stop the VM, send the wipe, start the VM | Command waits, runs on next check-in, then as C-1 | Command acknowledged after start; then C-1 rules |
| X-3 | Enroll secret rotated after the package was built | Rotate the fleet 10 secret in GitOps, then C-1 | fleetd comes back but can't enroll | Enrollment fails with an enroll secret error in the orbit log. Finding: the package must be rebuilt or staged again when the secret changes |
| X-4 | Host moved to another fleet before the reset | Transfer the host to a fleet without end user auth, then C-2 | Package enrolls into the fleet in its secret (fleet 10), not the one the host was in | Record which fleet the host lands in |
| X-5 | Package older fleetd | Build the package with an older fleetd, C-1 | fleetd comes back old, then updates itself | Record versions before and after |
| X-6 | End user auth turned off on the fleet | Fleet 10 off, C-2 | Enrolls with no prompt | Same as C-1 |
| X-7 | Staged package missing | C-4 without step 2 | Reset comes back without fleetd | No fleetd at the region screen; host never checks in. Confirms the staging is what brings it back |
| X-8 | BitLocker on before the reset | Turn on Fleet disk encryption, then C-1 | Reset still completes; record any recovery key prompt | Record outcome |


## UI and activity

| ID | Check | Pass when |
|---|---|---|
| U-1 | Host page during the reset: status, MDM status, last seen | Captured at each stage. Record that Fleet shows MDM On and connected while the host is mid-reset (v1 finding) |
| U-2 | Host page after re-enrollment: same host or new, end user, MDM, profiles, activity | Captured |
| U-3 | Activity feed: the custom command, MDM turned on again, any enrollment activity | Captured with timestamps |
| U-4 | Fleet's built-in Wipe action state ("Wiped") vs the custom command (no wipe state) | Recorded for the design (the custom command leaves no "Wiped" status) |


## API

| ID | Check | Pass when |
|---|---|---|
| A-1 | `fleetctl mdm run-command` with the library payloads | Library form rejected ("You can run only <Exec> command type."); bare `<Exec>` accepted (v1, NOTES D-8) |
| A-2 | `fleetctl get mdm-command-results` for each wipe | Status 200 recorded with time |
| A-3 | `POST /api/v1/fleet/hosts/:id/wipe` today accepts only `doWipe` and `doWipeProtected`. Run only against a throwaway host: if Fleet accepted it, the host would be wiped | Request with `wipe_type: doWipePersistProvisionedData` rejected; record the error (input for the API change in the story) |


## Permissions

| ID | Check | Pass when |
|---|---|---|
| P-1 | Which roles can send the custom wipe and run the staging script (admin, maintainer, fleet-level maintainer, technician, observer) | Recorded per role with an API-only user for each. Not run in v1 |


## Out of scope

Autopilot, Entra join, `doAutomaticRedeployment`, Windows 10, Wi-Fi-only devices, encrypted packages from the GUI
(Configuration Designer GUI not tested; `ICD.exe +Encrypted` packages failed in v1).


## Order and time

1. Phase 0: L-2 (about 30 min), then L-1, then L-3 (about 40 min). Stop and report if L-2b fails.
2. Phase 1: C-1, C-2, C-3, C-4 (about 1 hour each, two in parallel once L-1 passes). C-5 last.
3. Phase 2 and the UI, API, and Permissions checks alongside, where they reuse Phase 1 hosts.
4. Write up after each test. Commit after each test.


## Confirmation

- [ ] Phase 0 passed, with evidence
- [ ] C-1 to C-4 have results and screenshots of every user-facing screen
- [ ] RESULTS.md and drafts/ISSUE_UPDATE.md updated for the design review
