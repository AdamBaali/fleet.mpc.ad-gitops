# X-4: Host moved to another fleet before the reset

- **Started:** 2026-10-27T07:09:36Z
- **Objective:** Host 28 (c3 VM, no-bypass package, eua-user-2) is moved to No team, which has no end user authentication, then wiped
- **Expected:** The package re-enrolls the host into the fleet of its enroll secret (fleet 10), or Fleet keeps it in No team; record which

## Steps and evidence
- `01-host-before.txt`: `fleetctl api /api/v1/fleet/hosts/28 2>/dev/null | python3 -I tools/fleet-host-line.py`
- `02-transfer-to-no-team.txt`: `python3 -I tools/fleet-post.py /api/v1/fleet/hosts/transfer '{"team_id":null,"hosts":[28]}'`
- `03-host-after-transfer.txt`: `fleetctl api /api/v1/fleet/hosts/28 2>/dev/null | python3 -c 'import sys,json; h=json.load(sys.stdin)["host"];`
