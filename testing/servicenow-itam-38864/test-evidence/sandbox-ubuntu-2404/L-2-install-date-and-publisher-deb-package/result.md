# L-2: Install date and publisher: deb package

- **Started:** 2026-10-20T07:50:50Z
- **Objective:** Install hello, run the native report
- **Expected:** list_changed within 2 minutes of the recorded install. Publisher matches the package metadata

## Steps and evidence
- `01-install.txt`: `/repo/testing/servicenow-itam-38864/scripts/gt-linux.sh install`
- `02-rows-after-install.txt`: `snap install`
- `03-date-check.txt`: `python3 /repo/testing/servicenow-itam-38864/scripts/sandbox_check.py date /repo/testing/servicenow-itam-38864/`
- `04-publisher-check.txt`: `python3 /repo/testing/servicenow-itam-38864/scripts/sandbox_check.py publisher /repo/testing/servicenow-itam-3`

## Result: PASS

list_changed matched the recorded install. Publisher matched the package metadata

_Finished 2026-10-20T07:50:54Z_
