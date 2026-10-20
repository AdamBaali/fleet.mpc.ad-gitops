# X-1: Installer: download, checksum, autoload file

- **Started:** 2026-10-20T07:37:40Z
- **Objective:** Run the real Linux installer
- **Expected:** Exit 0, binary matches the pinned SHA-256, path listed once in /etc/osquery/extensions.load, root-owned 0755, restart scheduled

## Steps and evidence
- `01-first-run.txt`: `PATH=/repo/testing/servicenow-itam-38864/test-evidence/sandbox-fedora-41/_work/shim:$PATH SHIM_LOG=/repo/testi`
- `02-placed.txt`: `sha256sum /var/osquery/extensions/software_itam.ext; stat -c '%U:%G %a %n' /var/osquery /var/osquery/extension`

## Result: PASS

Installed the pinned build, listed once in /etc/osquery/extensions.load, restart scheduled through systemd-run

_Finished 2026-10-20T07:37:40Z_
