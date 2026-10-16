# L-3: Fleet's unlock script restores the machine

- **Date:** 2026-10-16
- **Objective:** Does `linux_unlock.sh` remove the lock state?
- **Expected:** nologin files gone, password unlocked, graphical target back, user can log in.

## Steps and evidence
- `00-unlock-applied.txt`: the real script applied (its scheduled reboot cancelled): no `/etc/nologin`, no `/run/nologin`, `graphical.target`, the `lab` account unlocked (`P`), sshd active.
- `01-after-unlock.txt`: key login as `lab` works again.
- `02-screenshot-unlock.png`: window screenshot.

## Result: PASS
