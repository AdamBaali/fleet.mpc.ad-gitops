# X-1c: Installer: wrong checksum is refused

- **Started:** 2026-10-20T07:37:40Z
- **Objective:** Run a copy of the installer with a wrong SHA-256
- **Expected:** Exit 6, installed binary unchanged

## Steps and evidence
- `01-bad-sha.txt`: `PATH=/repo/testing/servicenow-itam-38864/test-evidence/sandbox-fedora-41/_work/shim:$PATH SHIM_LOG=/repo/testi`

## Result: PASS

Checksum mismatch refused with exit 6, good binary left in place

_Finished 2026-10-20T07:37:41Z_
