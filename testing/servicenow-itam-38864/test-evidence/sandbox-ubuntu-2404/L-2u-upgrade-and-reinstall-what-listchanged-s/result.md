# L-2u: Upgrade and reinstall: what list_changed shows

- **Started:** 2026-10-20T09:01:09Z
- **Objective:** Upgrade hello (downgrade then upgrade, or reinstall when the repo has one version), then reinstall
- **Expected:** list_changed moves to the latest change each time, so it is not a first install date

## Steps and evidence
- `01-upgrade.txt`: `/repo/testing/servicenow-itam-38864/scripts/gt-linux.sh upgrade`
- `02-rows-after-upgrade.txt`: `snap upgrade`
- `03-upgrade-check.txt`: `python3 /repo/testing/servicenow-itam-38864/scripts/sandbox_check.py date /repo/testing/servicenow-itam-38864/`
- `04-uninstall.txt`: `/repo/testing/servicenow-itam-38864/scripts/gt-linux.sh uninstall`
- `05-reinstall.txt`: `/repo/testing/servicenow-itam-38864/scripts/gt-linux.sh reinstall`
- `06-rows-after-reinstall.txt`: `snap reinstall`
- `07-reinstall-check.txt`: `python3 /repo/testing/servicenow-itam-38864/scripts/sandbox_check.py date /repo/testing/servicenow-itam-38864/`

## Result: PASS

list_changed moved to the upgrade, then to the reinstall. Label it last changed and use first seen for first installed

_Finished 2026-10-20T09:01:21Z_
