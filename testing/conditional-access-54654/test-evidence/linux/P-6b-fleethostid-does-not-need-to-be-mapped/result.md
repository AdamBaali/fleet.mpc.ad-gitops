# P-6b: fleetHostID does not need to be mapped

- **Started:** 2026-10-07T18:10:12Z
- **Objective:** Check whether the second lookup can use the first lookup's fleetHostID without mapping it to the policy contract.
- **Expected:** Retest of an earlier finding that said it had to be mapped.

## Steps and evidence
- `01-unmapped-test.txt`: `cd ping/setup && bash .p6b.sh`
- `02-after-restore.txt`: `echo 'Policy restored; baseline sign-in:'`
- `03-restored-signin.txt` (VM): `bash /tmp/signin.sh cert`

## Result: **PASS**

With fleetHostID removed from the policy contract and not mapped, the second lookup still resolved ${ds.fleetByUuid.fleetHostID}, sign-in succeeded and the log had 0 WARN/ERROR lines. The earlier claim that it must be mapped was wrong and was removed from the guide.

_Finished 2026-10-07T18:10:36Z_
