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
- `05-t1852.png` (window screenshot: UTM / w1-bypass)
- `06-t1855.png` (window screenshot: UTM / w1-bypass)
- `07-t1857.png` (window screenshot: UTM / w1-bypass)
- `08-t1859.png` (window screenshot: UTM / w1-bypass)
- `09-t1901.png` (window screenshot: UTM / w1-bypass)
- `10-t1903.png` (window screenshot: UTM / w1-bypass)
- `11-t1906.png` (window screenshot: UTM / w1-bypass)
- `12-t1908.png` (window screenshot: UTM / w1-bypass)
- `13-t1910.png` (window screenshot: UTM / w1-bypass)
- `14-s191103.png` (window screenshot: UTM / w1-bypass)
- `15-s191133.png` (window screenshot: UTM / w1-bypass)
- `16-s191203.png` (window screenshot: UTM / w1-bypass)
- `17-s191233.png` (window screenshot: UTM / w1-bypass)
- `18-t1912.png` (window screenshot: UTM / w1-bypass)
- `19-s191303.png` (window screenshot: UTM / w1-bypass)
- `20-s191334.png` (window screenshot: UTM / w1-bypass)
- `21-s191404.png` (window screenshot: UTM / w1-bypass)
- `22-s191434.png` (window screenshot: UTM / w1-bypass)
- `23-t1915.png` (window screenshot: UTM / w1-bypass)
- `24-s191504.png` (window screenshot: UTM / w1-bypass)
- `25-s191535.png` (window screenshot: UTM / w1-bypass)
- `26-s191605.png` (window screenshot: UTM / w1-bypass)
- `27-s191635.png` (window screenshot: UTM / w1-bypass)
- `28-s191705.png` (window screenshot: UTM / w1-bypass)
- `29-t1917.png` (window screenshot: UTM / w1-bypass)
- `30-s191735.png` (window screenshot: UTM / w1-bypass)
- `31-s191806.png` (window screenshot: UTM / w1-bypass)
- `32-s191836.png` (window screenshot: UTM / w1-bypass)
- `33-s191906.png` (window screenshot: UTM / w1-bypass)
- `34-t1919.png` (window screenshot: UTM / w1-bypass)
- `35-s191936.png` (window screenshot: UTM / w1-bypass)
- `36-s192006.png` (window screenshot: UTM / w1-bypass)
- `37-s192037.png` (window screenshot: UTM / w1-bypass)
- `38-s192107.png` (window screenshot: UTM / w1-bypass)
- `39-s192137.png` (window screenshot: UTM / w1-bypass)
- `40-t1921.png` (window screenshot: UTM / w1-bypass)
- `41-s192207.png` (window screenshot: UTM / w1-bypass)
- `42-s192238.png` (window screenshot: UTM / w1-bypass)
- `43-s192308.png` (window screenshot: UTM / w1-bypass)
- `44-fleet-host-23-during-reset.jpg` (Fleet UI, Chrome)
- `45-fleet-host-23-activity.jpg` (Fleet UI, Chrome)
