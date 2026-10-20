# X-1c: Installer: wrong checksum is refused

- **Started:** 2026-10-20T07:36:58Z
- **Objective:** Run a copy of the installer with a wrong SHA-256
- **Expected:** Exit 6, installed binary unchanged

## Steps and evidence
- `01-bad-sha.txt`: `PATH=/repo/testing/servicenow-itam-38864/test-evidence/sandbox-ubuntu-2404/_work/shim:$PATH SHIM_LOG=/repo/tes`

## Result: PASS

Checksum mismatch refused with exit 6, good binary left in place

_Finished 2026-10-20T07:36:58Z_
