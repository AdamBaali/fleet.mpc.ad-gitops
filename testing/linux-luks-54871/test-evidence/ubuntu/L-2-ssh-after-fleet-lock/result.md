# L-2: SSH after Fleet's real Linux lock script

- **Date:** 2026-10-16
- **Objective:** Does `ee/server/service/embedded_scripts/linux_lock.sh` stop SSH logins? (customer comment on #35241)
- **Expected:** From the script: it kills the user's processes, runs `passwd -l`, writes /etc/nologin. Nothing in it touches sshd or authorized keys.

## Steps and evidence
- `00-lock-applied.txt`: the real script applied in the guest. It schedules a reboot in 10 s to text mode on Ubuntu with GDM; that timer was cancelled so the VM stayed up. State after: `/etc/nologin` and `/run/nologin` ("Locked by administrator"), the default target is `multi-user.target`, the `lab` account is locked (`passwd -S` shows `L`), sshd is still active.
- `01-ssh-after-lock.txt`: key login from the Mac. **`lab`: refused**, exit 255 (`fatal: Access denied for user lab by PAM account configuration [preauth]` in the sshd log). **`root`: still logs in** (`Accepted publickey for root`).
- `02-screenshot-lock-and-ssh.png`: window screenshot: lock state, then lab refused and root accepted.

## Result: PASS

Findings:
- The lock does not stop sshd and does not remove SSH keys. Non-root users are refused only because sshd's PAM stack enforces `/etc/nologin` and the locked account.
- **root is exempt from `/etc/nologin`**, so a root key login (or a root password login where allowed) still works on a locked machine. The customer's concern is right for root, not for ordinary users.
- Not tested: the machine after the scheduled reboot into text mode (the lock state is on disk and survives it; a hard power off before a sync can lose it).
