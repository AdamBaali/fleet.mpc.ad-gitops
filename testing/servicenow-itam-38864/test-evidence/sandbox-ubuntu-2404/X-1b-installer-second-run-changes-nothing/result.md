# X-1b: Installer: second run changes nothing

- **Started:** 2026-10-20T07:36:58Z
- **Objective:** Re-run the installer
- **Expected:** Already current, loader still has one line, no new restart

## Steps and evidence
- `01-second-run.txt`: `PATH=/repo/testing/servicenow-itam-38864/test-evidence/sandbox-ubuntu-2404/_work/shim:$PATH SHIM_LOG=/repo/tes`

## Result: PASS

Idempotent: nothing downloaded, no duplicate loader line, no restart

_Finished 2026-10-20T07:36:58Z_
