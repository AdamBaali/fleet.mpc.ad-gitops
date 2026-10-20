# X-7: Reinstall: install date and first_seen

- **Started:** 2026-10-20T07:38:03Z
- **Objective:** Install hello again
- **Expected:** first_seen keeps the first sighting. DEB install_date keeps the first install from dpkg.log, RPM moves

## Steps and evidence
- `01-reinstall.txt`: `/repo/testing/servicenow-itam-38864/scripts/gt-linux.sh reinstall`
- `02-rows-after-reinstall.txt`: `snap reinstall`
- `03-check.txt`: `python3 /repo/testing/servicenow-itam-38864/scripts/sandbox_check.py date /repo/testing/servicenow-itam-38864/`

## Result: PASS

first_seen kept (1792481867). install_date followed the event rule

_Finished 2026-10-20T07:38:08Z_
