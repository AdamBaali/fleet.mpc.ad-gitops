# L-1: Firefox name sent by a fleetd Mac

- **Started:** 2026-10-21T09:17:49Z
- **Objective:** Show the name a macOS host with fleetd sends for Firefox through the macos_firefox override, next to the name the main software_macos query gives
- **Expected:** macos_firefox returns Firefox.app, the main query returns Firefox

## Steps and evidence
- `01-fleet-version.txt`: `fleetctl api version 2>/dev/null | grep '"version"'`
- `02-host.txt`: `fleetctl api hosts/12 2>/dev/null | sed -n '/^{/,$p' | python3 -I -c 'import json,sys; h=json.load(sys.stdin)[`
- `03-parse-ini-exists.txt`: `fleetctl query --hosts MPC-Adam --exit --query "SELECT name FROM osquery_registry WHERE registry='table' AND n`
- `04-macos-firefox-query.txt`: `fleetctl query --hosts MPC-Adam --exit --query "$(cat testing/app-suffix-34088/tests/macos_firefox.sql)" 2>/de`
- `05-main-query-name.txt`: `fleetctl query --hosts MPC-Adam --exit --query "$(cat testing/app-suffix-34088/tests/main_name.sql)" 2>/dev/nu`
- `06-fleet-stored-firefox.txt`: `fleetctl api -F query=firefox software/versions 2>/dev/null | sed -n '/^{/,$p' | python3 -I -c 'import json,sy`

- `07-firefox-title-installer.txt`: the Firefox title in this fleet has the Firefox Fleet-maintained app installer, which is why the lab stores `Mozilla Firefox`

The host has fleetd, so parse_ini exists and the macos_firefox override replaces the main query's Firefox row. The override hard-codes the name Firefox.app (queries.go, macos_firefox). The lab stores Mozilla Firefox because this fleet has the Firefox Fleet-maintained app, and the hourly ReconcileMaintainedAppSoftwareNames job renames by the installer link. Without that installer link the bundle ID is shared with Firefox ESR, so the job skips it and the stored name stays Firefox.app (Fleet's own test, maintained_apps_test.go around line 1097).

## Result: PASS

On Fleet 4.93.0 a fleetd Mac sends Firefox.app through macos_firefox, while the main query gives Firefox. The .app name for Firefox is produced today by Fleet, not left over.

_Finished 2026-10-21T09:20:42Z_
