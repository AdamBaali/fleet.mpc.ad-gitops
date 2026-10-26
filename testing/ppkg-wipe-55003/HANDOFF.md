# Handoff: reset with a provisioning package

## State (2026-10-26, 20:30 UTC)
- Results so far: [RESULTS.md](RESULTS.md). Draft issue comment: `drafts/ISSUE_UPDATE.md` (not posted).
- Setup S-0 to S-7 done. E-1, E-1b, E-2, E-3 done. W-1, W-1b, W-6 BLOCKED by the lab: Windows rebuilt by a reset doesn't
  boot under UTM/QEMU on arm64. The wipe and the package persistence are proven; re-enrollment is not.
- Fleet hosts in fleet 10: 23 (W-1b, wiped), 24 (W-6, wiped). Both offline for good. Delete them before the next run.
- `fleetctl` uses an API token. fleetctl 4.93.2 against Fleet 4.93.0.

## Next steps
1. Get a physical x64 Windows 11 laptop (or an x64 Hyper-V VM) on Ethernet.
2. Build x64 MSIs (`tools/build-msis.sh amd64`) and packages (builder VM, ICD.exe, see S-6 evidence; use `-Encrypted`).
3. Run W-1b (bypass, host kept), W-2 (no bypass, host kept), W-3 (no bypass, host deleted, sign in as eua-user-2), W-6
   (staged by a Fleet script), W-5 (cloud variant). Screenshots of every user-facing screen and the Fleet host page.
4. Fix `scripts/stage-ppkg.ps1`: remove Users and Authenticated Users from `C:\Recovery`.

## Running services (keep them on)
- UTM VMs: ppkg-golden-oobe, ppkg-builder (stopped), w1-bypass and w6-stage (stopped, unbootable after reset; delete).
- Windows ISO: none yet. Adam wants the latest Windows 11 release, not 24H2 (the 24H2 ISO is in the Trash).
- `ppkg-wipe-idp` (Docker, port 9080 on all interfaces). Check: `docker ps --filter name=ppkg-wipe-idp`. Stop: `docker compose -f idp/docker-compose.yml down`.

## Teardown
- UTM: `ppkg-golden-oobe`, every clone, the builder VM if made for this project, the USB images.
- Local files: MSIs, WCD project folders, `.ppkg` files (they hold the enroll secret).
- Fleet: hosts in "Windows Reset Lab", then the fleet file. Rotate its enroll secret if a package left the Mac.
- Fleet: remove `mdm.end_user_authentication` from `default.yml` unless another lab uses it.
- GitHub: secret `FLEET_WINDOWS_RESET_LAB_ENROLL_SECRET` and its `workflow.yml` line.
- Mock IdP: see IDP_SETUP.md "Teardown".

## Rules learned
- Delete the host in Fleet before a reset when the test needs a first-time enrollment (NOTES.md D-1).
- Don't merge a PR that adds a secret variable before the secret is set. A failed apply blocks every fleet.
- `fleetctl get fleets` skips fleets whose name has an emoji. Use `fleetctl api /api/v1/fleet/fleets`.
