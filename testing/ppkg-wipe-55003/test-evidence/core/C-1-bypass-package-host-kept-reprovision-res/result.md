# C-1: Bypass package, host kept, reprovision reset

**Objective:** PKG-B applied at the region screen of a generalized VM in fleet 10 (end user authentication on), user `lab1` with data, MDM On. Send `doWipePersistProvisionedData` from Fleet and watch the host come back  
**Expected:** fleetd running at the region screen after the reset; same Fleet host with a newer `last_enrolled_at`; MDM On and connected; no prompt; `lab1` gone  
**Run:** 2026-10-27T00:12:04Z to 2026-10-27T00:42:23Z

## Evidence

- `01-region-screen.png`, `03-trust-prompt.png` (VM screens): package opened from Shift+F10 at the region screen
- `05-fleet-host-before.txt`, `021-fleet-host-before.jpg` (Fleet UI): host 25 in fleet 10, MDM On (manual), no end user
- `21-wipe-command.txt`: `fleetctl mdm run-command` with `payloads/doWipePersistProvisionedData.xml`
- `22-wipe-result.txt`: command acknowledged, status 200
- `watch/` (VM screens): first and last screen of the reset
- `fleet-poll.log`: host state every 30 s
- `22-fleet-host-activities.txt`, `23-fleet-host-after.txt`, `031-fleet-host-after.jpg` (Fleet UI): host after the reset
- `29-live-query-after.txt`: live query at the region screen (`queries/after-reset.sql`)

## What happened

Host 25 enrolled in fleet 10 at 00:11:02 with MDM On (manual) and no end user. `lab1` (local admin) and two marker files
were created so the wipe had user data to remove.

**Timeline (UTC):** wipe sent 00:25:08, acknowledged 00:25:47, host offline 00:35, fleetd re-enrolled 00:38:11 at the
region screen (same host 25, new hostname), Windows MDM re-enrolled 00:39:05. 13 minutes. No prompt on any screen; the
last screen is the region screen.

At 00:38:44 Fleet refused an MDM command for this host ("one or more hosts have MDM turned off") while the host API
still said On (manual): Windows MDM was re-enrolling. A minute later the host was back in `fleetctl get hosts --mdm`.

**Live query at the region screen:** built-in local users only (`lab1` gone), 0 markers left, fleetd RUNNING,
`fleet-agent-b-plain.ppkg` still in `ProgramData\Microsoft\Provisioning`.

**Fleet UI after the reset:** same host page, new hostname, Online, MDM On (manual). "Added to Fleet" says 4 minutes
ago: it shows `last_enrolled_at`; `created_at` is still 00:10:59. The activity feed has a new "MDM was turned on" entry
and nothing that says the host was wiped (U-4).

## Result: PASS

Bypass package and `doWipePersistProvisionedData` from Fleet: the host came back as the same Fleet host 25 at the region
screen in 13 minutes, with no prompt, fleetd reinstalled, MDM re-enrolled, `lab1` and its data gone, and the package
kept.
