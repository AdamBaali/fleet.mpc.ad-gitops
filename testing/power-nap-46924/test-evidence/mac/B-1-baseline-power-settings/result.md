# B-1: Baseline power settings

- **Started:** 2026-10-20T10:44:51Z
- **Objective:** Record the laptop's power settings before any run
- **Expected:** Power Nap, tcpkeepalive and standby values saved

## Steps and evidence
- `01-host.txt`: `fleetctl api /api/v1/fleet/hosts/20 2>/dev/null | python3 -c 'import json,sys; h=json.load(sys.stdin)["host"];`
- `02-pmset-custom.txt`: `fleetctl query --hosts macbook-air --exit --timeout 90s --query "SELECT json_result FROM pmset WHERE getting =`
- `03-power-source.txt`: `fleetctl query --hosts macbook-air --exit --timeout 90s --query "SELECT state, charging, charged, percent_rema`

Read remotely through Fleet live queries (fleetd pmset table, osquery battery table), not on the laptop. Power Nap 1, tcpkeepalive 1, standby 1 and hibernatemode 3 on battery and AC. System sleep after 1 minute on both. womp 0 on battery.

## Result: INFO

Power Nap on, tcpkeepalive on, standby on, sleep 1 min, hibernatemode 3 (battery and AC). Restore these at teardown if changed

_Finished 2026-10-20T10:45:41Z_
