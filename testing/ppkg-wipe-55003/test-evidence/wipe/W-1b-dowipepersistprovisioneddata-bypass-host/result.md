# W-1b: doWipePersistProvisionedData, bypass, host kept (rerun)

- **Started:** 2026-10-26T18:51:25Z
- **Objective:** Reset host 23 (E-1b) with doWipePersistProvisionedData; does fleetd come back and re-enroll on its own
- **Expected:** Back at the region screen with fleetd running; host 23 checks in before any user exists

## Steps and evidence
- `01-before-fleet.txt`: `fleetctl api /api/v1/fleet/hosts/23 2>/dev/null | python3 -c 'import json,sys; h=json.load(sys.stdin)["host"];`
- `02-before-vm.txt`: `tools/vm-exec.sh w1-bypass 'Get-Service "Fleet osquery" | Format-Table Name,Status | Out-String; "users: " + (`
- `03-send-wipe.txt`: `date -u +%FT%TZ; fleetctl mdm run-command --hosts=AB61C369-9644-4E83-91AC-A43146484151 --payload=payloads/doWi`

First send at 18:51:44 failed: You can run only <Exec> command type. The library payload is wrapped in <syncml><syncbody>; Fleet accepts only a top-level <Exec> (payloads/README.md). Resent unwrapped.
- `04-send-wipe-exec.txt`: `date -u +%FT%TZ; fleetctl mdm run-command --hosts=AB61C369-9644-4E83-91AC-A43146484151 --payload=payloads/doWi`
