# W-1: doWipePersistProvisionedData, bypass, host kept

- **Started:** 2026-10-26T18:24:01Z
- **Objective:** Reset the E-1 host with doWipePersistProvisionedData and see whether fleetd comes back and re-enrolls on its own
- **Expected:** Back at the region screen with fleetd running; the same host checks in before any user exists

## Steps and evidence
- `01-before-fleet.txt`: `fleetctl api /api/v1/fleet/hosts/21 2>/dev/null | python3 -c 'import json,sys; h=json.load(sys.stdin)["host"];`
- `02-before-vm.txt`: `tools/vm-exec.sh e1-bypass 'Get-Service "Fleet osquery" | Format-Table Name,Status | Out-String; "users: " + (`
- `03-payload.txt`: `cat payloads/doWipePersistProvisionedData.xml`
- `04-send-wipe.txt`: `date -u +%FT%TZ; fleetctl mdm run-command --hosts=6F2E8E70-A9E1-4993-9A2C-24BCD553152A --payload=payloads/doWi`

Fleet refused the command: one or more hosts have MDM turned off. Host 21 showed MDM On (manual) but connected_to_fleet false; fleetctl get hosts --mdm listed host 22 (the E-2 clone) instead. Both VMs are clones of one non-generalized image: same MachineGuid d63a9cda-... and machine SID, different DMClient DeviceClientId. Fleet keys Windows MDM enrollments on mdm_hardware_id (schema.sql: UNIQUE KEY idx_type (mdm_hardware_id); microsoft_mdm.go MDMWindowsInsertEnrolledDevice ON DUPLICATE KEY UPDATE), so host 22 enrolling took over host 21 MDM row. Lab artifact: real laptops have unique hardware IDs. Same risk for cloned VDI images that skip sysprep.

## Result: BLOCKED

First attempt: host 21 lost its MDM connection to host 22 because the clones share a Windows MDM hardware ID. Rebuilding the golden image with sysprep /generalize and rerunning E-1, E-2, then W-1.

_Finished 2026-10-26T18:27:05Z_
