# PN-1: Large install, lid closed, battery

- **Started:** 2026-10-20T11:05:08Z
- **Objective:** Policy automation installs Google Chrome while the laptop sleeps with the lid closed on battery
- **Expected:** Download fails across DarkWakes, as reported in the issue thread

## Steps and evidence
- `01-start.txt`: `cat <fleet script result> pn4a-start.txt`

Started as PN-4a (idle sleep on AC, lid open) and became PN-1 before the Chrome policy ran again: Adam unplugged the charger and closed the lid at about 2026-10-20T11:07:48Z (reported in chat). Chrome deleted by a Fleet script at 13:04:39 local (11:04:39Z). The last policy check was 10:42:12Z, so the next is due about 11:42Z, inside the lid-closed window.

Refetch requested at 2026-10-20T11:08:00Z (Adam's suggestion), so the policies run at the next check-in instead of about 11:42Z. The check-in itself still has to happen in a DarkWake.
- `02-fleet-watch-changes.txt`: `awk '{s=$0; sub(/^[^ ]+ /,"",s)} s!=p{print; p=s}' /private/tmp/claude-502/-Users-adam-Library-Application-Sup`
- `03-failed-install-result.txt`: `fleetctl api /api/v1/fleet/software/install/9b46eeea-b096-46eb-930d-20838a6d8f9d/results 2>/dev/null | python3`
- `04-activities.txt`: `fleetctl api /api/v1/fleet/hosts/20/activities 2>/dev/null | python3 -c 'import json,sys
for a in reversed(json.load(sys.stdin)["activities"]):
  d=a.get("details") or {}; print(a["created_at"], a["type"], d.get("software_title") or d.get("script_name") `

Fleet side (lid still closed, laptop on battery):
- 11:50:23Z check-in in a DarkWake. Chrome policy fails, install queued 11:50:22Z, fleetd picks it up 11:51:08Z.
- 12:07:53Z last check-in Fleet saw. Check-ins only at 11:17:50Z, 11:50:23Z and 12:07:53Z, each online for 1 to 2 minutes.
- 12:23:26Z fleetd reports "Error: Software installer download failed." (`failed_install`), about 16 minutes after the last check-in. Fleet re-queues the install at once (PN-6).
- Still needed: orbit.stderr.log and pmset -g log for 11:45Z to 12:30Z, from the laptop once the lid opens.
