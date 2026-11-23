# Handoff: windows-mdm-migration-59195

## State
Lab tests of the migration script are done, except anything that needs Intune. Results in `RESULTS.md`. The review draft
for the PR is `drafts/PR_REVIEW.md` (not posted). Host 37 is back on Fleet MDM.

## Next steps
1. Post the review on the PR (you).
2. With an Intune tenant: enroll `mig1` in Intune and run the script for the real step 2.

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
