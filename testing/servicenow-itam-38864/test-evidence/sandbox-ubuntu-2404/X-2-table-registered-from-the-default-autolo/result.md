# X-2: Table registered from the default autoload file

- **Started:** 2026-10-20T07:36:58Z
- **Objective:** Load the extension the way osqueryd does under fleetd: no --extension flag
- **Expected:** software_itam active with every documented column

## Steps and evidence
- `01-registry.txt`: `/osq/opt/osquery/bin/osqueryd -S --json --extensions_require=software_itam --extensions_timeout=20 "SELECT nam`
- `02-columns.txt`: `/osq/opt/osquery/bin/osqueryd -S --json --extensions_require=software_itam --extensions_timeout=20 "SELECT nam`

## Result: PASS

Autoloaded from /etc/osquery/extensions.load with all 12 columns

_Finished 2026-10-20T07:37:00Z_
