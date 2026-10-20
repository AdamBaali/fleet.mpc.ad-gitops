# S-0: Sandbox facts

- **Started:** 2026-10-20T07:51:31Z
- **Objective:** Record the environment these results come from
- **Expected:** Facts saved

## Steps and evidence
- `01-os-release.txt`: `grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release; uname -m`
- `02-osquery-version.txt`: `/osq/opt/osquery/bin/osqueryd --version`
- `03-prior-installs.txt`: `grep -h ' install hello' /var/log/dpkg.log* 2>/dev/null || echo 'no earlier hello install in dpkg.log'`
- `04-report-sql.txt`: `printf '%s\n' "$NATIVE_SQL"`

No fleetd or Fleet server here. osquery runs the report SQL from the repo in shell mode (osqueryd -S). The package manager is real.

## Result: INFO

Environment recorded

_Finished 2026-10-20T07:51:31Z_
