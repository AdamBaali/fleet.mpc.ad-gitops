# PN-1: Large install, lid closed, battery

- **Started:** 2026-10-20T11:05:08Z
- **Objective:** Policy automation installs Google Chrome while the laptop sleeps with the lid closed on battery
- **Expected:** Download fails across DarkWakes, as reported in the issue thread

## Steps and evidence
- `01-start.txt`: `cat <fleet script result> pn4a-start.txt`

Started as PN-4a (idle sleep on AC, lid open) and became PN-1 before the Chrome policy ran again: Adam unplugged the charger and closed the lid at about 2026-10-20T11:07:48Z (reported in chat). Chrome deleted by a Fleet script at 13:04:39 local (11:04:39Z). The last policy check was 10:42:12Z, so the next is due about 11:42Z, inside the lid-closed window.

Refetch requested at 2026-10-20T11:08:00Z (Adam's suggestion), so the policies run at the next check-in instead of about 11:42Z. The check-in itself still has to happen in a DarkWake.
