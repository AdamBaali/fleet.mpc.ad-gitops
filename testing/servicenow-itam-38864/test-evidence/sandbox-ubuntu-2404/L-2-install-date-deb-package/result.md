# L-2: Install date: deb package

- **Started:** 2026-10-20T07:37:00Z
- **Objective:** Install hello with the package manager, read the native report and software_itam
- **Expected:** Native and extension install dates within 2 minutes of the recorded install

## Steps and evidence
- `01-install.txt`: `/repo/testing/servicenow-itam-38864/scripts/gt-linux.sh install`
- `02-rows-after-install.txt`: `snap install`
- `03-check.txt`: `python3 /repo/testing/servicenow-itam-38864/scripts/sandbox_check.py date /repo/testing/servicenow-itam-38864/`

## Result: PASS

Native list_changed and extension install_date both match the recorded install

_Finished 2026-10-20T07:37:05Z_
