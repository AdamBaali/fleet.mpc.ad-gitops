# Handoff: macOS Power Nap (#46924)

## State (2026-10-20)
Ready for enrollment. Power Nap Lab is applied in Fleet (fleet ID 8, 0 hosts). Checked through the API:
- Chrome policy installs Google Chrome, swiftDialog policy installs swiftDialog, flag-file policy runs `power-nap-timestamps.sh`.
- Enroll secret `FLEET_POWER_NAP_LAB_ENROLL_SECRET` is set.
- Two reports, `Power Nap test - pmset settings` (hourly) and `Power Nap test - power source` (10 minutes), record power settings without anyone at the Mac.
- `scripts/collect.sh` saves B-1 and each run's logs with the `_framework` helpers. Tried on the lab Mac (orbit 1.61.0, osquery 5.24.0), evidence not kept.

Nothing run on the MacBook Air yet.

## Next steps
1. Enroll the MacBook Air: install `~/Downloads/fleet-power-nap-lab.pkg` (built 2026-10-20 with `scripts/build-pkg.sh`, scripts on). No MDM needed: fleetd runs the installs and scripts.
2. B-1: `testing/power-nap-46924/scripts/collect.sh baseline`.
3. C-1, lid open, on power: delete Google Chrome, wait for the policy run, then `collect.sh window C-1 "<start>"`.
4. PN-1: delete Google Chrome, close the lid on battery at once, leave it overnight. Next morning `collect.sh window PN-1 "<lid closed time>"` and save the Fleet activities for the same window.
5. PN-2 to PN-6. PN-3 starts with `sudo touch /var/tmp/fleet-pn-script`. PN-7 only if PN-1 fails.
6. Write ISSUE_UPDATE.md from RESULTS.md.

## Running services (keep them on)
None yet.

## Teardown
- Restore any `pmset` changes (`sudo pmset -b powernap <original>`, values from B-1).
- Unenroll the MacBook Air or move it out of Power Nap Lab.
- Remove `fleets/power-nap-lab.yml`, `fleets/power-nap-lab/`, the policy and script files, the workflow env line and the repository secret.
- Delete `/var/tmp/fleet-pn-script.log` on the Mac.

## Rules learned
- Record `pmset -g log` for the same time window as the orbit log. The thread's proof is lining the two up.
