# Handoff: macOS Power Nap (#46924)

## State (2026-10-20)
Ready for enrollment. Power Nap Lab is applied in Fleet (fleet ID 8, 0 hosts). Checked through the API:
- Chrome policy installs Google Chrome, swiftDialog policy installs swiftDialog, flag-file policy runs `power-nap-timestamps.sh`.
- Enroll secret `FLEET_POWER_NAP_LAB_ENROLL_SECRET` is set.
- Two reports, `Power Nap test - pmset settings` (hourly) and `Power Nap test - power source` (10 minutes), record power settings without anyone at the Mac.
- `scripts/collect.sh` saves B-1 and each run's logs with the `_framework` helpers. Tried on the lab Mac (orbit 1.61.0, osquery 5.24.0), evidence not kept.

Runs on the MacBook Air started 2026-10-20, see Next steps.

## Next steps
Done: B-1, C-1, PN-1 (reproduced), PN-6 (2026-10-20). PN-2 PARTIAL (2026-10-21): the install never reached fleetd, and an FMA update dropped it. Host 20 (MacBook Air) is enrolled in Power Nap Lab. Laptop logs are read through Fleet scripts (root), so nobody needs to be at the laptop except to close or open the lid.
1. PN-2 rerun: swiftDialog is absent and its policy already fails, so the automation will not queue it again. Reinstall swiftDialog with the lid open (policy passes), then delete it, refetch and close the lid on battery.
2. PN-3: `touch /var/tmp/fleet-pn-script` by Fleet script, refetch, close the lid on battery. Read `/var/tmp/fleet-pn-script.log` for gaps.
3. PN-4: PN-1 with the charger connected.
4. PN-5: `sudo pmset -b powernap 0`, repeat PN-1. Restore to 1 after (B-1).
5. PN-7 (PN-1 failed): wrap the install in `caffeinate -s` and repeat PN-1.
6. Write ISSUE_UPDATE.md from RESULTS.md.

Side finding (C-1): an orbit restart mid-download (here about 90 s after MDM enrollment) drops the download with no error line. Fleet re-sends the install.

## Running services (keep them on)
None yet.

## Teardown
- Restore any `pmset` changes (`sudo pmset -b powernap <original>`, values from B-1).
- Unenroll the MacBook Air or move it out of Power Nap Lab.
- Remove `fleets/power-nap-lab.yml`, `fleets/power-nap-lab/`, the policy and script files, the workflow env line and the repository secret.
- Delete `/var/tmp/fleet-pn-script.log` on the Mac.

## Rules learned
- Record `pmset -g log` for the same time window as the orbit log. The thread's proof is lining the two up.
