# L-2: SSH after Fleet's real Linux lock script

- **Date:** 2026-10-16
- **Objective:** Does `ee/server/service/embedded_scripts/linux_lock.sh` stop SSH logins? (#35241 comment from customer-reedtimmer.)
- **Expected:** Per the script: it kills the user's processes, runs `passwd -l`, writes /etc/nologin; it does nothing about sshd or keys.

## Steps and evidence
- `00-lock-applied.txt`: the real script applied in the guest (it schedules a reboot to text mode on Ubuntu with GDM; here a cold restart was done instead) and the resulting state.
- `01-ssh-after-lock.txt`: SSH key logins after the lock and a cold restart: lab is refused, root is refused.

## Result: PASS

Observed: see the lines above. `pam_nologin` blocks non-root users when sshd's PAM stack includes it; root is exempt from /etc/nologin, so a root key login is not affected. The lock does not stop sshd or disable authorized keys.
