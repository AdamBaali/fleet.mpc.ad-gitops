# X-8: first_seen survives an osquery restart

- **Started:** 2026-10-20T07:37:05Z
- **Objective:** Read first_seen in two separate osquery processes
- **Expected:** Same value for every row

## Steps and evidence
- `01-second-process.txt`: `snap restart`
- `02-compare.txt`: `python3 -c "import json; a={(r['source'],r['identifier'],r['path']):r['first_seen'] for r in json.load(open('/`

## Result: PASS

first_seen identical across two processes for every row. Reboot not tested in a container

_Finished 2026-10-20T07:37:09Z_
