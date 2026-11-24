# Handoff: windows-mdm-migration-59195

## State
Lab tests of the migration script are done, except anything that needs Intune. Results in `RESULTS.md`. The review draft
for the PR is `drafts/PR_REVIEW.md` (not posted). Host 37 is back on Fleet MDM.

## Next steps
1. Post the review on the PR (you).
2. With an Intune tenant: enroll `mig1` in Intune and run the script for the real step 2.

## Lab host for other sessions
- Fleet: host id 37, hostname `DESKTOP-6OUEH8Q`, serial `mig1`, fleet "Device IDs Lab" (id 15), Windows 11 Pro 26300
  arm64, Fleet MDM On (manual), no user signed in (region screen).
- Fleet MCP (`fleet` server in this repo's local Claude Code config): `get_host` with `host_id` 37, and
  `run_live_query` with `host_ids` 37. The MCP user is Observer+, so it can read and run live queries but not run
  scripts.
- Scripts: saved script 120 is the migration script. Running scripts needs an admin token (`out/run-script.sh 37 120`).
- VM: QEMU `mig1` on base `~/Documents/fleet-lab/base/win11-mig-golden.qcow2`. Start:
  `FG=1 tools/qemu-boot.sh mig1 ~/Documents/fleet-lab/base/win11-mig-golden.qcow2` (background task, sandbox off).
  Guest agent: `tools/qga.sh mig1 '<powershell>'`. VNC: 127.0.0.1:5901. UUID 40E5E620-8C4D-44BD-B4F5-B48B35F64C3E,
  MAC 52:54:00:cc:cb:5e.

## Running services (keep them on)
- QEMU VM `mig1` (Fleet host 37, Device IDs Lab). Check: `testing/_framework/bin/status.sh`.
  Stop: `tools/qga.sh mig1 'Stop-Computer -Force'`.

## Teardown
- VM folders `~/Documents/fleet-lab/vm/mig1` and `~/Documents/fleet-lab/vm/mig-golden`.
- Keep the base disk `~/Documents/fleet-lab/base/win11-mig-golden.qcow2` (13.3 GB, read-only). It is the lab's only
  Windows base now.
- ISOs in `~/Documents/fleet-lab/iso/` (8.5 GB Windows, 121 MB guest tools). Delete the Windows ISO if disk is tight.
- Saved script 120 in the Device IDs Lab fleet. The next GitOps run removes it.
- Fleet host 37 in Device IDs Lab.
- API-only user "Fleet MCP" (id 10): its token prefix was printed once in a session log. Recreate it if that matters.

## Rules learned
- Clones of `win11-mig-golden` share an MDM hardware ID. `sysprep /generalize` any second clone before enrolling it.
- Run Fleet API one-liners in bash, not zsh: zsh's `echo` rewrites the backslashes in script output.
- The guest agent from UTM's guest tools runs as x64 PowerShell. Use the 64-bit registry view in scripts it runs.
