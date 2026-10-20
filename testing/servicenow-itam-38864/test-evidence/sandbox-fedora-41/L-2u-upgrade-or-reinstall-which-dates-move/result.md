# L-2u: Upgrade or reinstall: which dates move

- **Started:** 2026-10-20T07:37:52Z
- **Objective:** Upgrade hello (downgrade then upgrade, or reinstall when the repo has one version)
- **Expected:** Native moves to the upgrade. Extension keeps the first install for DEB (dpkg.log), moves for RPM

## Steps and evidence
- `01-upgrade.txt`: `/repo/testing/servicenow-itam-38864/scripts/gt-linux.sh upgrade`
- `02-rows-after-upgrade.txt`: `snap upgrade`
- `03-check.txt`: `python3 /repo/testing/servicenow-itam-38864/scripts/sandbox_check.py date /repo/testing/servicenow-itam-38864/`

## Result: PASS

Native moved to the upgrade time. Extension install_date followed the expected rule (event)

_Finished 2026-10-20T07:37:59Z_
