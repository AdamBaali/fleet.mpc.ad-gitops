# Handoff: fleetd-healthcheck-59727

## State
- Both scripts are in `lib/windows/scripts/` and listed under `controls.scripts` in `fleets/device-ids-lab.yml`.
- T-1 passed. T-2 to T-5 need the scripts applied and a token that can run scripts in fleet 15.

## Next steps
1. Merge this branch so GitOps saves both scripts in fleet 15.
2. Put a maintainer or admin token in `private/fleet.env` (`FLEET_URL`, `FLEET_API_TOKEN`). The Observer+ token can
   live query but can't run scripts.
3. From this folder: `tools/run-script.sh 37 fleetd-healthcheck-main.ps1` (T-3), then
   `tools/run-script.sh 37 fleetd-healthcheck.ps1` (T-4). Save each output under `test-evidence/`.
4. Live query for the archive (T-5) and fill in RESULTS.md.

## Running services (keep them on)
Host 37: QEMU VM `mig1` on the lab Mac, shared with another test. Don't shut it down.

## Teardown
- Remove the two `controls.scripts` entries from `fleets/device-ids-lab.yml` and delete both scripts from
  `lib/windows/scripts/`.
- Delete `C:\Windows\SystemTemp\fleetd_healthcheck_*.zip` on host 37.
