# C-1: Bypass package, host kept, reprovision reset

- **Started:** 2026-10-27T00:12:04Z
- **Objective:** PKG-B applied at the region screen on a generalized QEMU VM (fleet 10, end user auth on), lab1 signed in, MDM On. Then doWipePersistProvisionedData from Fleet and watch the host come back
- **Expected:** fleetd running at the region screen after the reset; same Fleet host with a newer last_enrolled_at; MDM On and connected; no prompt; lab1 profile gone

## Steps and evidence

Applied fleet-agent-b-plain.ppkg from Shift+F10 (start D:fleet-agent-b-plain.ppkg) at about 00:10 UTC. The first try typed # for \ (guest keyboard layout), so 02 shows Windows not finding the file. On the second, Windows showed Provisioning failure 0x800700b7 (already exists, 04), yet the package was applied: fleetd Running, the package kept in C:\ProgramData\Microsoft\Provisioning, and Fleet host 25 (WIN-N21FERVGUUK, UUID ED712DCB-...) enrolled in fleet 10 at 00:11:02 with MDM On (manual) and connected, no end user. Likely a second apply of the same package; v1 E-1 never showed it.
- `021-fleet-host-before.jpg` (Fleet UI, Chrome)
- `21-wipe-command.txt`: `fleetctl mdm run-command --hosts WIN-N21FERVGUUK --payload payloads/doWipePersistProvisionedData.xml`
- `22-wipe-result.txt`: `fleetctl get mdm-command-results --id=44a24549-fb1b-451a-9b8b-f99eae19263b`
- `23-mdm-get-after.txt`: `fleetctl mdm run-command --hosts WIN-6950OA7B9F8 --payload payloads/local/get-devdetail.xml`
- `24-mdm-get-after-uuid.txt`: `fleetctl mdm run-command --hosts ED712DCB-E688-47A9-B129-E983573EE9EE --payload payloads/local/get-devdetail.x`

At 00:38:44 Fleet refused an MDM command for this host ("one or more hosts have MDM turned off") although the host API said On (manual): Windows MDM was re-enrolling at that moment. A minute later the host was back in fleetctl get hosts --mdm.
- `25-mdm-get-after-retry.txt`: `fleetctl mdm run-command --hosts ED712DCB-E688-47A9-B129-E983573EE9EE --payload payloads/local/get-devdetail.x`
- `28-live-query-after.txt`: `fleetctl query --hosts ED712DCB-E688-47A9-B129-E983573EE9EE --exit --timeout 90s --query "SELECT (SELECT group`
- `29-live-query-after.txt`: `fleetctl query --hosts ED712DCB-E688-47A9-B129-E983573EE9EE --exit --timeout 90s --query "$(cat queries/after-`
- `031-fleet-host-after.jpg` (Fleet UI, Chrome)

Setup was not finished as lab1 through the UI: in the later setup screens QMP letters were dropped (Enter, Tab and F10 worked). lab1 was created through the guest agent instead (local admin, no password), with marker files at C:\lab-marker.txt and C:\Users\lab1-data\marker.txt, so the wipe had user data to remove.

Timeline (UTC): wipe sent 00:25:08, acknowledged 200 at 00:25:47 (wipe-result), Resetting and Installing screens in watch/ from about 00:26, host offline 00:35, fleetd re-enrolled 00:38:11 at the region screen (same host 25, new hostname), Windows MDM re-enrolled 00:39:05 (mdm_enrolled activity, 22). Reset to back in Fleet: 13 minutes. No prompt on any screen (watch/037 is the region screen).

Live query at the region screen (live-query-after): local users Administrator, DefaultAccount, Guest, WDAGUtilityAccount (lab1 gone), 0 markers left, fleetd service RUNNING, fleet-agent-b-plain.ppkg still in ProgramData\Microsoft\Provisioning, uptime 219 s.

Fleet UI after the reset (031): same host page, new hostname, Online, MDM On (manual). The Vitals "Added to Fleet" says 4 minutes ago: it shows last_enrolled_at; created_at is still 00:10:59. Activity feed shows a new "MDM was turned on" entry and nothing that says the host was wiped (the custom command leaves no wipe status, U-4).

## Result: PASS

Bypass package + doWipePersistProvisionedData from Fleet: reset in 13 min, fleetd reinstalled itself and the host came back as the same Fleet host 25 at the region screen with no prompt, MDM re-enrolled (mdm_enrolled 00:39:05), lab1 and its data gone, package kept.

_Finished 2026-10-27T00:42:23Z_
