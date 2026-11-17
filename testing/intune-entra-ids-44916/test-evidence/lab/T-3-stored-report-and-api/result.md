# T-3: Stored report and API

- **Started:** 2026-11-09T15:40:03Z
- **Objective:** Both reports store one row per host and return it through the report and host endpoints
- **Expected:** Rows match the faked IDs; report_clipped is false

## Steps and evidence
- `01-expected.txt`: `tools/qga.sh ids1 'Get-Content C:\ids\expected.json'`
- `02-host.txt`: `scripts/fleet-api.sh '/api/v1/fleet/hosts/35' | python3 -c 'import sys,json; h=json.load(sys.stdin)["host"]; p`
- `03-intune-all-paged.txt`: `scripts/fleet-api.sh '/api/v1/fleet/reports/2793/report?page=0&per_page=500' | python3 -m json.tool`
- `04-entra-all-paged.txt`: `scripts/fleet-api.sh '/api/v1/fleet/reports/2794/report?page=0&per_page=500' | python3 -m json.tool`
- `05-intune-all-export.txt`: `scripts/fleet-api.sh '/api/v1/fleet/reports/2793/report' | python3 -m json.tool`
- `06-intune-host.txt`: `scripts/fleet-api.sh '/api/v1/fleet/hosts/35/reports/2793' | python3 -m json.tool`
- `07-entra-host.txt`: `scripts/fleet-api.sh '/api/v1/fleet/hosts/35/reports/2794' | python3 -m json.tool`
- `08-compare.txt`: `python3 scripts/compare-t3.py ids1 35 2793 2794`
- `09-control-wrong-expected.txt`: `scripts/t3-control.sh ids1`

## Result: PASS

Host 35 in Device IDs Lab (Fleet 4.94.0, fleetd osquery 5.24.1): both stored reports return the faked IDs through /reports/:id/report (paged and unpaged) and /hosts/:id/reports/:id; report_clipped false; enrollment key returned. With wrong expected IDs the comparison fails on all four value checks.

_Finished 2026-11-09T15:41:24Z_
