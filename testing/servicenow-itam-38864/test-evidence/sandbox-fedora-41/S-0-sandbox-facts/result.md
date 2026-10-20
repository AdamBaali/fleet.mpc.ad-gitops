# S-0: Sandbox facts

- **Started:** 2026-10-20T07:37:40Z
- **Objective:** Record the environment these results come from
- **Expected:** Facts saved

## Steps and evidence
- `01-os-release.txt`: `grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release; uname -m`
- `02-osquery-version.txt`: `/osq/opt/osquery/bin/osqueryd --version`
- `03-prior-installs.txt`: `grep -h ' install hello' /var/log/dpkg.log* 2>/dev/null || echo 'no earlier hello install in dpkg.log'`
- `04-mounts.txt`: `findmnt -no TARGET,FSTYPE,OPTIONS / 2>/dev/null || cat /proc/mounts | head -5`

No fleetd or Fleet server here. osquery runs in shell mode (osqueryd -S), the extension is the pinned build, and the package manager is real. systemctl and systemd-run are shims that log calls.

## Result: INFO

Environment recorded

_Finished 2026-10-20T07:37:40Z_
