# X-4: Host moved to another fleet before the reset

- **Started:** 2026-10-27T07:09:36Z
- **Objective:** Host 28 (c3 VM, no-bypass package, eua-user-2) is moved to No team, which has no end user authentication, then wiped
- **Expected:** The package re-enrolls the host into the fleet of its enroll secret (fleet 10), or Fleet keeps it in No team; record which

## Steps and evidence
- `01-host-before.txt`: `fleetctl api /api/v1/fleet/hosts/28 2>/dev/null | python3 -I tools/fleet-host-line.py`
- `02-transfer-to-no-team.txt`: `python3 -I tools/fleet-post.py /api/v1/fleet/hosts/transfer '{"team_id":null,"hosts":[28]}'`
- `03-host-after-transfer.txt`: `fleetctl api /api/v1/fleet/hosts/28 2>/dev/null | python3 -c 'import sys,json; h=json.load(sys.stdin)["host"];`
- `04-c3-automatic-repair.png` (VM screen)
- `05-host-28-back-to-fleet-10.txt`: `python3 -I tools/fleet-post.py /api/v1/fleet/hosts/transfer '{"team_id":10,"hosts":[28]}'`

Attempt 1 on host 28 stopped before the wipe. The c3 VM booted to "Automatic Repair couldn't repair your PC" (04), a lab fault: c3 last ran with virtio-gpu after C-3, and the Mac slept for 35 minutes during this boot. Host 28 went back to fleet 10 and X-4 moves to host 29 (c4 VM).

Attempt 2: host 29 (c4 VM, MSI-enrolled, bypass package staged in C:\Recovery\Customizations in C-4, reset twice in C-4 and C-5).
- `06-host-29-before.txt`: `fleetctl api /api/v1/fleet/hosts/29 2>/dev/null | python3 -I tools/fleet-host-line.py`
- `07-host-29-staged-package.txt`: `fleetctl query --hosts 1FCA0238-3AEF-4D8E-9574-3E800F01701E --exit --timeout 90s --query "$(cat queries/after-`
- `08-host-29-to-no-team.txt`: `python3 -I tools/fleet-post.py /api/v1/fleet/hosts/transfer '{"team_id":null,"hosts":[29]}' && fleetctl api /a`
- `09-wipe-command.txt`: `fleetctl mdm run-command --hosts 1FCA0238-3AEF-4D8E-9574-3E800F01701E --payload payloads/doWipePersistProvisio`
- `010-fleet-host-mid-reset.jpg` (Fleet UI, Chrome)
- `11-orbit-log-while-secret-rotated.png` (VM screen; X-3 had fleet 10's secret rotated at this time)
- `11-host-29-after.txt`: `fleetctl api /api/v1/fleet/hosts/29 2>/dev/null | python3 -c 'import sys,json; h=json.load(sys.stdin)["host"];`
- `12-live-query-after.txt`: `fleetctl query --hosts 1FCA0238-3AEF-4D8E-9574-3E800F01701E --exit --timeout 90s --query "$(cat queries/after-`
- `014-fleet-host-after.jpg` (Fleet UI, Chrome)
- `13-code-enroll-orbit-known-host.txt`: `git -C /Users/adam/Documents/GitHub/fleet show fleet-v4.93.0:server/datastore/mysql/hosts.go | sed -n 2612,262`

Timeline (UTC): host 29 moved to No team 08:09:08, wipe sent 08:09:2x, offline 08:11:59, reset done and region screen about 08:30. From 08:30 to 08:58 fleet 10's secret was rotated for X-3, so fleetd's enroll failed here too (11). After the GitOps secret was restored at 08:58:06, fleetd enrolled at 08:59:11: same host 29, MDM On, connected, and still in No team (host-29-after, fleet-host-after). The package's secret belongs to fleet 10, but Fleet kept the host in the fleet it was in. At fleet-v4.93.0 EnrollOrbit updates a known host without setting team_id (code-enroll-orbit-known-host); the secret's fleet applies only when Fleet creates a new host. Live query: fleetd RUNNING, staged package still in C:\Recovery\Customizations, built-in users only.

## Result: PASS

A known host comes back in the fleet it was in (No team here), not the fleet of the package's enroll secret; Fleet sets the fleet only for new hosts

_Finished 2026-10-27T09:02:07Z_
