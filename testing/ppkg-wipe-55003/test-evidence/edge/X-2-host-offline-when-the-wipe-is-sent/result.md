# X-2: Host offline when the wipe is sent

- **Started:** 2026-10-27T07:09:34Z
- **Objective:** Host 25 (c1 VM, bypass package, reset once in C-1) is shut down. Send doWipePersistProvisionedData, then start the VM
- **Expected:** Command waits, runs at the next check-in, then the host comes back as in C-1

## Steps and evidence
- `01-host-before.txt`: `fleetctl api /api/v1/fleet/hosts/25 2>/dev/null | python3 -I tools/fleet-host-line.py`
- `02-vm-is-off.txt`: `test -e out/qemu/c1/pid && kill -0 $(cat out/qemu/c1/pid) 2>/dev/null && echo running || echo stopped`
- `03-wipe-command.txt`: `fleetctl mdm run-command --hosts ED712DCB-$(cut -c10- out/qemu/c1/uuid | tr a-z A-Z) --payload payloads/doWipe`
- `04-command-result.txt`: `fleetctl get mdm-command-results --id=47594579-364a-4241-9aad-889780d13c58 2>&1 | grep -v -i version | sed "s#`
- `05-live-query-after.txt`: `fleetctl query --hosts ED712DCB-E688-47A9-B129-E983573EE9EE --exit --timeout 90s --query "$(cat queries/after-`
- `06-mdm-after.txt`: `fleetctl api /api/v1/fleet/hosts/25 2>/dev/null | python3 -c 'import sys,json; h=json.load(sys.stdin)["host"];`
- `007-fleet-host-after.jpg` (Fleet UI, Chrome)
- `008-fleet-activity-after.jpg` (Fleet UI, Chrome)
- `09-vm-screen-after.png` (VM screen)

Timeline (UTC): VM off, wipe sent 07:09:36 (03); Fleet said hosts run it at next check-in. VM started 07:09:45, host online 07:10:19, and the earlier read of the command result showed it delivered at 07:10:40. The Mac then slept from about 07:17 to 07:52, which paused the VM mid-reset (watch frames show the reset resume at Resetting this PC 29%). fleetd re-enrolled 08:04:59 as the same host 25 with a new hostname, MDM On, in fleet 10, no end user (07-mdm-after). Live query (06): fleetd RUNNING, kept package fleet-agent-b-plain.ppkg, built-in users only, 0 markers. Reading the command result fails with the NULL bug from C-5 (05). About 20 minutes of awake time from delivery to re-enrollment.

Activity feed (008): the custom command shows at the time it was sent ("about 1 hour ago"), not when the host ran it, then "MDM was turned on". Nothing marks the hour the host spent waiting for it, or the reset.

## Result: PASS

An offline host runs the queued wipe at its next check-in and comes back as the same host with MDM on; the feed shows only when the command was sent

_Finished 2026-10-27T08:12:11Z_
