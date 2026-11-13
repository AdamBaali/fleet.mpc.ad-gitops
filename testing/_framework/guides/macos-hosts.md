# macOS hosts

Sources: `testing/power-nap-46924`, `testing/servicenow-itam-38864` (`gt-macos.sh`), `testing/mac-readiness`,
`testing/app-suffix-34088`.

A Mac VM can't test sleep. Use real hardware for anything about Power Nap, lid close, battery, or wake, and read the logs
through Fleet scripts so nobody has to sit at the Mac.


## Install fleetd

```bash
fleetctl package --type=pkg --fleet-url="$FLEET_URL" --enroll-secret="$SECRET" \
  --enable-scripts --fleet-desktop --outfile=fleetd.pkg
```

`--enable-scripts` is required if a policy or test runs a Fleet script. `testing/power-nap-46924/scripts/build-pkg.sh`
reads the fleet's secret at build time with `fleetctl api /api/v1/fleet/teams/$ID/secrets`. The fleet ID is hard-coded
there, so change it for a new fleet.

Default paths: `/opt/orbit/bin/orbit/macos/stable/orbit`, orbit log `/var/log/orbit/orbit.stderr.log` (root only).


## Sleep and wake evidence

```bash
pmset -g log | awk -v s='YYYY-MM-DD HH:MM' 'substr($0,1,16) >= s' | grep -E ' (Sleep|Wake|DarkWake) '
pmset -g custom; pmset -g batt; pmset -g assertions
sudo awk ... /var/log/orbit/orbit.stderr.log
```

The proof is lining up orbit's errors with the DarkWake and Sleep times for the same window. orbit timestamps use `T`
where pmset uses a space, so convert before comparing. `testing/power-nap-46924/scripts/collect.sh baseline` and
`collect.sh window <ID> "<YYYY-MM-DD HH:MM>"` gather it.

Test levers: `sudo pmset -b powernap 0` (restore afterwards) and `caffeinate -s` around an install.

Known behavior: an orbit restart in the middle of a download drops it without an error line, and a Fleet-maintained app
version update silently drops a pending install.


## Software ground truth

`testing/servicenow-itam-38864/scripts/gt-macos.sh dmg-install|pkg-install|fma-wait|open|uninstall|...` records each event
with `gt-lib.sh`. It uses pinned VLC DMGs and Firefox pkgs, and covers a Fleet-maintained app, an App Store app, and an
unsigned app. Pick apps whose publisher is a company, so no person's name reaches the results.


## Report logic without a Mac

`testing/mac-readiness/tools/sqlite-logic-check.py` loads fixtures into SQLite with Fleet's osquery schema and checks SQL
and CASE logic. It doesn't check osquery's virtual tables, so run the report on a real Mac too.


## Screenshots

- Terminal output: `testing/_framework/tools/macterm.sh <out.png> <scriptfile>` opens a new Terminal window, waits until
  it is idle, captures only that window, and closes it.
- Apps: `winid "<App name>"` then `screencapture -x -o -l<id> out.png`. Build `winid` and `maskbox` once (see
  [../README.md](../README.md)).
- Mask sign-in codes, tokens, IP addresses, and personal data with `maskbox` before a picture enters `test-evidence/`.


## Keeping the lab Mac usable

- `caffeinate -dims` for long runs. An idle sleep pauses every VM.
- `testing/_framework/bin/status.sh` shows what other sessions use before you start a VM.
- Commit only your own paths: `git commit -- <paths>`.
