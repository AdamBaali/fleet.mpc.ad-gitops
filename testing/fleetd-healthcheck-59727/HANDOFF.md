# Handoff: fleetd-healthcheck-59727

## State
- T-1 to T-5 and T-4b pass on host 37. Results in RESULTS.md, raw output in `test-evidence/windows/`.
- The update for the pull request is in `drafts/pr-comment.md`, for Adam to post.

## Next steps
1. Post `drafts/pr-comment.md` on the pull request.
2. Optional: run the script by hand in an elevated session on host 37 over VNC, and on an x64 host.
3. Teardown once the pull request merges.

## Running services (keep them on)
Host 37: QEMU VM `mig1` on the lab Mac, shared with another test. Don't shut it down.

## Teardown
- Remove the two `controls.scripts` entries from `fleets/device-ids-lab.yml` and delete both scripts from
  `lib/windows/scripts/`.
- Delete `C:\Windows\Temp\fleetd_healthcheck_*.zip` on host 37.
