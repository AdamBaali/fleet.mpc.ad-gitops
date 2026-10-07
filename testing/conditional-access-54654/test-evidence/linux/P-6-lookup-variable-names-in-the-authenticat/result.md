# P-6: Lookup variable names in the authentication policy

- **Started:** 2026-10-07T18:09:32Z
- **Objective:** Find which names PingFederate accepts in the Fleet lookup paths and issuance criteria, and what happens with the guide's wording.
- **Expected:** Names of the form ${ad.<adapter ID>.CN} and ${ds.<source ID>.<attribute>} work; ${hostUUID} and ${fleetHostID} do not.

## Steps and evidence
- `01-policy-as-configured.txt`: `curl -sk -u Administrator:$PING_ADMIN_PASSWORD -H 'X-XSRF-Header: PingFederate' https://localhost:9999/pf-admi`
- `02-baseline-signin.txt` (VM): `bash /tmp/signin.sh cert`
- `03-variant-A-apply.txt`: `echo A:\ guide\ wording\ \$\{hostUUID\}\ in\ lookup\ 1; (cd ping/setup && bash ./.var-A.sh | tail -1)`
- `04-variant-A-signin.txt` (VM): `bash /tmp/signin.sh cert`
- `05-variant-A-log.txt`: `echo 'PingFederate server log, decoded (lines written during that sign-in):'; docker exec pingfederate sh -c '`
- `06-variant-C-apply.txt`: `echo C:\ second\ criterion\ fleetHostUUID\ equals\ \$\{hostUUID\}\ \(guide\ wording\); (cd ping/setup && bash `
- `07-variant-C-signin.txt` (VM): `bash /tmp/signin.sh cert`
- `08-variant-C-log.txt`: `echo 'PingFederate server log, decoded (lines written during that sign-in):'; docker exec pingfederate sh -c '`
- `09-variant-D-apply.txt`: `echo D:\ guide\ wording\ \$\{fleetHostID\}\ in\ lookup\ 2; (cd ping/setup && bash ./.var-D.sh | tail -1)`
- `10-variant-D-signin.txt` (VM): `bash /tmp/signin.sh cert`
- `11-variant-D-log.txt`: `echo 'PingFederate server log, decoded (lines written during that sign-in):'; docker exec pingfederate sh -c '`
- `12-restore-and-signin.txt`: `echo 'Working policy restored.'; echo`
- `13-restored-signin.txt` (VM): `bash /tmp/signin.sh cert`

## Result: **PASS**

PingFederate accepts only ad.<adapter ID>.<attribute> and ds.<source ID>.<attribute> names (it lists the available keys in its log). The guide wording ${hostUUID} and ${fleetHostID} gives Unknown Key; a criterion with value ${hostUUID} is compared as literal text. See P-6b for the fleetHostID mapping correction.

_Finished 2026-10-07T18:10:36Z_
