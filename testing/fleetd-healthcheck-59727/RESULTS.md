# Results: fleetd health check scripts

## T-1 Baseline
## Result: PASS
2026-11-24, live query on host 37 (online):

| Item | Value |
|---|---|
| `C:\Program Files\Orbit\secret.txt` | absent |
| `secret-orbit-node-key.txt`, non-empty | present |
| `HKLM\SOFTWARE\FleetDM\Orbit` | absent |
| `Fleet osquery` service `Environment` value | present |
| osqueryd running outside `C:\Program Files\Orbit` | none |
| MDM enrollment keys with a `ProviderID` | 4 |
| `fleetd_healthcheck_*` in `C:\Windows\SystemTemp` or `C:\Windows\Temp` | none |

## T-2 Scripts saved
## Result: NOT-RUN

## T-3 Negative control
## Result: NOT-RUN

## T-4 Pull request version
## Result: NOT-RUN

## T-5 Archive
## Result: NOT-RUN
