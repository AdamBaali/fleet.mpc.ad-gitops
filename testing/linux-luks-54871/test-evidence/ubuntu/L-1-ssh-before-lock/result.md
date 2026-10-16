# L-1: SSH key login works on the unlocked machine (baseline)

- **Date:** 2026-10-16
- **Objective:** Baseline for the #35241 comment that users can still SSH into a locked machine.
- **Expected:** key login works for the user and for root.

## Steps and evidence
- `00-setup.txt`: sshd active, `PasswordAuthentication yes`, the sshd PAM file's `nologin` line, the lab account unlocked, no /etc/nologin.
- `01-ssh.txt`: key login from the Mac as `lab` and as `root` both succeed. The test key is a throwaway key kept in the Mac's secrets folder and removed after the test.
- `02-screenshot-baseline.png`: window screenshot.

## Result: PASS
