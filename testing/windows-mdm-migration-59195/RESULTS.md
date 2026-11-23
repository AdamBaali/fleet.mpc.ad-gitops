# Results: windows-mdm-migration-59195

Script under test: `windows-migrate-to-fleet-mdm.ps1` from the PR, head `d44c91c`, with only `$FleetServerUrl` set to the
lab Fleet. Saved script 120 in the Device IDs Lab fleet. Lab Fleet 4.95.0, Windows MDM on, programmatic enrollment on,
automatic migration off.

Host: QEMU VM `mig1`, Windows 11 Pro 26300 arm64, fresh install from Microsoft's ISO, no TPM, at the region screen with
no user signed in. Fleet host 37. fleetd from the Device IDs Lab MSI (orbit 1.64.0).

No Intune tenant: the "old MDM" is either a removed Fleet enrollment or a fake leftover key. The Intune unenroll in step 2
is not tested.

## L-1: Lab host (2026-11-23): PASS
- **Steps:** Installed Windows with `vm/qemu-install.sh`, then UTM guest tools 0.1.271 from a hot-plugged USB at the
  region screen (`/S`, exit 0). Saved the disk as base `win11-mig-golden.qcow2`, booted `mig1` on an overlay, installed
  fleetd with `msiexec /qn` (exit 0).
- **Actual:** Install took about 61 minutes to the region screen. fleetd enrolled in 10 s. Fleet MDM turned on about
  20 s later, with no user signed in.
- **Evidence:** `test-evidence/lab/L-1` to `L-4`.
- **Finding:** Fleet MDM enrollment works at the region screen with no user session. The "no one signed in" concern in
  the review doesn't apply to this setup.

## R-1: OMADM values the script reads (2026-11-23): PASS
- **Steps:** Read the Fleet enrollment's OMADM account in the 64-bit registry view.
- **Actual:** `Protected\AddrInfo\Addr = https://fleet.mpc.ad/api/mdm/microsoft/management`,
  `Protected\ConnInfo\LastSessionResult = 0`, plus `ServerLastSuccessTime` and `ServerLastAccessTime`.
- **Evidence:** `test-evidence/lab/L-4-after-fleet-mdm.txt`.
- **Finding:** The script's "checked in" and wrong-server checks read real values. Drop that item from the review.

## T-9: Rerun on an enrolled host (2026-11-23): PASS
- **Expected:** exit 0, no unenroll.
- **Actual:** exit 0 in 4 s: "Already enrolled in Fleet MDM; no changes made. First management session with Fleet
  succeeded."
- **Evidence:** `test-evidence/lab/T-9-already-enrolled.txt`.

## T-3: No MDM, enroll path (2026-11-23): PASS
- **Steps:** Removed the Fleet enrollment with `UnregisterDeviceWithManagement(0)` through a Fleet script, then ran the
  script. Programmatic enrollment on, so fleetd could race it.
- **Actual:** exit 0 in 56 s. Step 3 waited 48 s for Fleet to show MDM Off, step 4 called `RegisterDeviceWithManagement`
  (0x00000000), and the health check saw the first session. The script enrolled before fleetd did. A second run (T-7b)
  took 73 s, 63 s of it waiting for MDM Off.
- **Evidence:** `test-evidence/lab/T-3a`, `T-3b`, `T-7b`.

## T-8: Leftover enrollment key (2026-11-23): PASS (confirms the review finding)
- **Steps:** With no MDM, added a key like an old MDM leaves: `ProviderID=MS DM Server`, `EnrollmentState=3`, a UPN, a
  discovery URL, no OMADM account. Ran the script, then refetched and watched for 3 minutes.
- **Expected (review):** the script finds it only after step 2 and exits 5; the host stays without MDM.
- **Actual:** The script listed the key under "MDM enrollments before" (`FleetSeesOn True`), went on to step 2, then
  exited 5. After a refetch Fleet showed "On (manual) Intune" for 3 minutes while the host had no MDM, and fleetd never
  enrolled it. Removing the key and rerunning recovered the host (exit 0 in 25 s).
- **Evidence:** `test-evidence/lab/T-8a` to `T-8d`.
- **Finding:** With a real Intune enrollment, step 2 would remove Intune before the check, leaving the host with no MDM.
  The check belongs in preflight.

## T-7: Group Policy auto-enrollment set (2026-11-23): PASS
- **Steps:** With no MDM, set `AutoEnrollMDM=1` under `Policies\Microsoft\Windows\CurrentVersion\MDM` and ran the script.
- **Actual:** exit 2 in 4 s, no change to `Enrollments`.
- **Evidence:** `test-evidence/lab/T-7-gpo.txt`, cleanup in `T-7b-cleanup.txt`.

## T-10: Pasted as an ad hoc script (2026-11-23): FAIL (documentation)
- **Steps:** `POST /api/latest/fleet/scripts/run` with the script contents.
- **Actual:** 422 "Script is too large. It's limited to 10,000 characters". The script is 17,632 characters. As a saved
  script it runs (saved scripts allow 500,000).
- **Finding:** Say in the header that it must be added as a saved script, not pasted into Run script.

## Not run
- Intune unenroll (step 2 against a real old MDM): no Intune tenant.
- Manual enrollment mode (`enable_turn_on_windows_mdm_manually`): global setting, managed by GitOps.
- Transient errors after the unenroll, the 300 s timeout, and the ConfigMgr check.
