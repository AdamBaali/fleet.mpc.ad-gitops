# L-1: SSH works before the lock

- **Date:** 2026-10-16
- **Objective:** Baseline for the #35241 comment that users can still SSH into a locked machine.
- **Expected:** Key login works for lab and root.

## Steps and evidence
- `00-setup.txt`: lab SSH key installed for lab and root (a test key kept in the Mac's secrets folder); sshd settings; the `pam_nologin` line in the sshd PAM file.
- `01-ssh.txt`: key login from the Mac.

## Result: PARTIAL
