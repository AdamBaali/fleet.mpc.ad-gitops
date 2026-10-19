# Handoff: macOS Power Nap (#46924)

## State
Folder, test plan and desk review (D-1) done. Lab fleet drafted (`fleets/power-nap-lab.yml`, `lib/macos/policies/power-nap-test.policies.yml`, `lib/macos/scripts/power-nap-timestamps.sh`), not applied. Nothing run on a Mac.

## Next steps
1. Add the repository secret `FLEET_POWER_NAP_LAB_ENROLL_SECRET`, then push. The push changes Fleet config, so it runs the live apply.
2. Enroll the MacBook Air in Power Nap Lab. Run B-1.
3. Run C-1, then PN-1. Save `orbit.stderr.log`, `pmset -g log` and the Fleet activity for the same window.
4. Run PN-2 to PN-6. PN-7 only if PN-1 fails.
5. Write ISSUE_UPDATE.md from RESULTS.md.

## Running services (keep them on)
None yet.

## Teardown
- Restore any `pmset` changes (`sudo pmset -b powernap <original>`, values from B-1).
- Unenroll the MacBook Air or move it out of Power Nap Lab.
- Remove `fleets/power-nap-lab.yml`, `fleets/power-nap-lab/`, the policy and script files, the workflow env line and the repository secret.
- Delete `/var/tmp/fleet-pn-script.log` on the Mac.

## Rules learned
- Record `pmset -g log` for the same time window as the orbit log. The thread's proof is lining the two up.
