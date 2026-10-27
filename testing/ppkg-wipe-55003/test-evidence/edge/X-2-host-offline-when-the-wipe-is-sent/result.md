# X-2: Host offline when the wipe is sent

- **Started:** 2026-10-27T07:09:34Z
- **Objective:** Host 25 (c1 VM, bypass package, reset once in C-1) is shut down. Send doWipePersistProvisionedData, then start the VM
- **Expected:** Command waits, runs at the next check-in, then the host comes back as in C-1

## Steps and evidence
- `01-host-before.txt`: `fleetctl api /api/v1/fleet/hosts/25 2>/dev/null | python3 -I tools/fleet-host-line.py`
- `02-vm-is-off.txt`: `test -e out/qemu/c1/pid && kill -0 $(cat out/qemu/c1/pid) 2>/dev/null && echo running || echo stopped`
- `03-wipe-command.txt`: `fleetctl mdm run-command --hosts ED712DCB-$(cut -c10- out/qemu/c1/uuid | tr a-z A-Z) --payload payloads/doWipe`
