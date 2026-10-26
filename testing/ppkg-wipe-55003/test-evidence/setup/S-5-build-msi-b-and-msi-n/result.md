# S-5: Build MSI-B and MSI-N

- **Started:** 2026-10-26T17:08:03Z
- **Objective:** Two arm64 fleetd MSIs for Windows Reset Lab, one with --bypass-end-user-auth
- **Expected:** Both build; only MSI-B carries ORBIT_BYPASS_END_USER_AUTH=true

## Steps and evidence
- `01-fleetctl-version.txt`: `fleetctl --version | head -1`
- `02-build.txt`: `tools/build-msis.sh arm64`
- `03-bypass-flag.txt`: `for m in b n; do printf "msi-$m ORBIT_BYPASS_END_USER_AUTH occurrences: "; LC_ALL=C grep -a -c ORBIT_BYPASS_EN`

## Result: PASS

Both arm64 MSIs built with fleetctl 4.93.2. Only MSI-B carries ORBIT_BYPASS_END_USER_AUTH=true.

_Finished 2026-10-26T17:09:56Z_
