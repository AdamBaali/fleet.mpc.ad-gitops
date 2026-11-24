# Handoff: fleetd-healthcheck-59727

## State
- All three scripts pass on real hosts through Fleet: Windows (host 37), Linux (host 38), macOS (host 12). Results in
  RESULTS.md, raw output in `test-evidence/`.
- The pull request has every fix from these runs. It is a draft until the owner marks it ready.

## Next steps
1. Mark the pull request ready for review.
2. Optional: run each script by hand (elevated PowerShell, `sudo bash`, `sudo sh` on macOS) and on an x64 Windows host.
3. Teardown once the pull request merges.

## Running services (keep them on)
- Host 37: QEMU VM `mig1` on the lab Mac, shared with another test.
- Host 38: Docker container `fleet-linux-test` in a cloud session. It stops when that session ends. Fleet then shows the
  host offline.

## Teardown
- GitOps: remove the health check entries under `controls.scripts` in `fleets/device-ids-lab.yml` and
  `fleets/ping-duo-lab.yml`, and delete `lib/windows/scripts/fleetd-healthcheck*.ps1`,
  `lib/linux/scripts/fleetd-healthcheck.sh` and `lib/macos/scripts/fleetd-healthcheck*.sh`.
- Fleet: delete host 38 (`vm`, Ubuntu, Device IDs Lab).
- Hosts: delete the archives the runs left: `/tmp/fleetd_healthcheck_*` on the lab Mac and
  `C:\Windows\Temp\fleetd_healthcheck_*.zip` on host 37.
- Secrets: rotate the Ping Duo Lab enroll secret. macOS `pgrep -lf` output in two script runs on the lab Mac (M-1 and a
  diagnostic) included it, and Fleet stores script output. Rotate the admin API token used for the runs.

## Rules learned
- macOS `pgrep` skips its own ancestors: use `-a` to find orbit from a script Fleet runs.
- macOS `pgrep -l` and `ps -o args` can show a process's environment. Never write them to an archive.
- Fleet's script timeout is 5 minutes. Time any `log show` search on a real Mac before shipping it.
- An auto-updated orbit runs from `bin/orbit/<platform>/<channel>/orbit`.
