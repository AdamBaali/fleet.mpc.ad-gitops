# X-9: Cost of one software_itam query

- **Started:** 2026-10-20T07:37:09Z
- **Objective:** Time a full query
- **Expected:** Seconds, not minutes

## Steps and evidence
- `01-timing.txt`: `/usr/bin/time -v /osq/opt/osquery/bin/osqueryd -S --json --extensions_require=software_itam --extensions_timeo`

## Result: INFO

Timing recorded in the output. Watchdog limits only apply under fleetd

_Finished 2026-10-20T07:37:10Z_
