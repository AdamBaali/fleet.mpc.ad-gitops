# Handoff: reset with a provisioning package

## State (2026-10-27, 05:15 UTC)
- Results: [RESULTS.md](RESULTS.md). Draft issue comment: `drafts/ISSUE_UPDATE.md` (not posted).
- Lab moved from UTM to Homebrew QEMU 11.1.2 (NOTES, "Lab fix"). Phase 0 and Phase 1 pass: L-2C, L-3, C-1, C-2r, C-3,
  C-4, C-5. C-2 (first attempt) BLOCKED by a lab display fault.
- Fleet hosts in fleet 10: 21 to 26 are stale (v1 and the failed C-2); 25 (C-1), 28 (C-3), 29 (C-4, C-5) are VMs now
  shut down. Delete them before the next run.
- `fleetctl` uses an API token. fleetctl 4.93.2 against Fleet 4.93.0.

## Next steps
1. Phase 2 edge cases from TEST_PLAN.md: X-2 (offline host), X-3 (enroll secret rotated), X-4 (host moved to another
   fleet), X-5 (older fleetd), X-6 (end user auth off), X-7 (staged package missing), X-8 (BitLocker). X-1 is covered
   by C-3.
2. UI, API and permissions checks: U-1 to U-4, A-3 (built-in wipe API with a persist type), P-1 (roles).
3. Optional: one run on x64 hardware before any guide change.

## How to run a VM (QEMU)
The QEMU tools and their rules now live in `testing/_framework/vm/` (README there); `tools/q*` are links to them.
- Base disk: the UTM golden image `ppkg-golden-oobe` (has UTM guest tools: guest agent and drivers).
- `FG=1 tools/qemu-boot.sh <vm> <base.qcow2>` as a long-lived background task. ramfb only (see NOTES lessons).
- Generalize through the guest agent, hot-plug the package USB at the region screen
  (`tools/qmp.sh <vm> usb out/usb-pkg-<b|n>-plain.img true`), open it from Shift+F10.
- Watch resets with `tools/qemu-watch.sh` and `tools/fleet-poll.sh`; check with `queries/after-reset*.sql`.

## Running services (keep them on)
- UTM VMs: ppkg-golden-oobe (base disk for QEMU; don't start it in UTM while a QEMU VM uses it), ppkg-builder,
  ppkg-golden-v0 (arm B leftover; delete).
- QEMU VMs in `out/qemu/` (git-ignored): smoke, c1 to c4. All shut down. Delete the folders to reclaim about 60 GB.
- `ppkg-wipe-idp` (Docker, port 9080 on all interfaces). Check: `docker ps --filter name=ppkg-wipe-idp`. Stop: `docker compose -f idp/docker-compose.yml down`.

## Teardown
- UTM: `ppkg-golden-oobe`, `ppkg-golden-v0`, the builder VM, the USB images. QEMU: `out/qemu/`. Homebrew: `qemu`, `swtpm`.
- Local files: MSIs, WCD project folders, `.ppkg` files (they hold the enroll secret).
- Fleet: hosts in "Windows Reset Lab", then the fleet file. Rotate its enroll secret if a package left the Mac.
- Fleet: remove `mdm.end_user_authentication` from `default.yml` unless another lab uses it.
- GitHub: secret `FLEET_WINDOWS_RESET_LAB_ENROLL_SECRET` and its `workflow.yml` line.
- Mock IdP: see IDP_SETUP.md "Teardown".

## Rules learned
- Delete the host in Fleet before a reset when the test needs a first-time enrollment (NOTES.md D-1).
- Don't merge a PR that adds a secret variable before the secret is set. A failed apply blocks every fleet.
- `fleetctl get fleets` skips fleets whose name has an emoji. Use `fleetctl api /api/v1/fleet/fleets`.
