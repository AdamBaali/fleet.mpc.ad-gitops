# Handoff: Intune and Entra device IDs

## State (2026-11-09)
- Research done ([NOTES.md](NOTES.md)). T-1 and T-2 pass on the lab VM ([RESULTS.md](RESULTS.md)).
- `fleets/device-ids-lab.yml` ("Device IDs Lab") and `lib/windows/reports/device-ids.reports.yml` are on this branch. The lab dry run passes. Not applied.
- T-4 and T-5 are blocked: no Entra or Intune tenant.

## How to run
- VM: `FG=1 tools/qemu-boot.sh ids1 <ppkg-golden-oobe base disk>` from this folder, as a long-lived task. Windows stays at the region screen; the guest agent runs as SYSTEM, which is all the tests need.
- osquery: `out/dl/osquery-5.24.1.msi`, installed in the VM at `C:\Program Files\osquery`.
- T-1 and T-2: `scripts/run-t1-t2.sh ids1`.
- Lab API: `testing/android-pin-57607/private/fleet.env` holds the lab URL and token. The default `fleetctl` context points at a different, non-lab Fleet: use a lab-only config with `--config`, never the default.

## Next steps
1. Add the GitHub secret `FLEET_DEVICE_IDS_LAB_ENROLL_SECRET`, then merge the PR so "Device IDs Lab" applies.
2. T-3: install fleetd in `ids1` with that secret, run `fake-ids.ps1 setup`, wait for the reports, then pull them through the API.
3. T-4: ask the customer to run both queries in their stage Fleet and compare with `dsregcmd /status` and the Intune portal, or ask the engineer who built the #44917 IdP vitals work, who tested on an Entra-joined device.
4. Raise with product: expose the Entra ID Fleet already collects on `GET /hosts/:id`.

## Running services (keep them on)
- QEMU VM `ids1` (`out/qemu/ids1/`). Stop: `tools/qga.sh ids1 'Stop-Computer -Force'`.

## Teardown
- VM `ids1` and `out/` (about 6 GB, git-ignored). Fakes are already cleared (`fake-ids.ps1 clear`).
- Fleet: "Device IDs Lab", its hosts, `fleets/device-ids-lab.yml`, `lib/windows/reports/device-ids.reports.yml`.
- GitHub: secret `FLEET_DEVICE_IDS_LAB_ENROLL_SECRET` and its `workflow.yml` line.

## Rules learned
- Check which `fleetctl` context is active before any command.
