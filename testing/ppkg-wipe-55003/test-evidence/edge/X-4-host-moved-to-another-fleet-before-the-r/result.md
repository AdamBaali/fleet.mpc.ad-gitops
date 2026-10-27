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
