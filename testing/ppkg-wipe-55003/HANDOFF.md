# Handoff: reset with a provisioning package

## State (2026-10-27, 09:45 UTC)
- Results: [RESULTS.md](RESULTS.md). Draft issue comment: `drafts/ISSUE_UPDATE.md` (not posted).
- Phase 0 to 2 done. Phase 2: X-2, X-3, X-4, X-6, X-7 PASS; X-5 NOT-RUN (needs a package with an older fleetd);
  X-8 BLOCKED (no TPM in the QEMU arm VMs). U-1 to U-4, A-3, P-1 PASS (U-4 and P-1 from code at fleet-v4.93.0).
- Fleet 10 is back to its GitOps settings: enroll secret restored after X-3, end user authentication on after X-6
  (both checked through the API).
- Fleet hosts in fleet 10: 25 (c1, no fleetd after X-7), 26 and 28 (broken VMs), 30 (c4, new host from X-6). 21 to
  24 and 27 are no longer in Fleet. Delete 25, 26, 28 and 30 before the next run.
- VMs: c1 and c4 are running at the region screen; c2 and c3 don't boot (Automatic Repair); smoke is unused.
- `fleetctl` uses an API token. fleetctl 4.93.2 against Fleet 4.93.0.

## Next steps
1. Review RESULTS.md and drafts/ISSUE_UPDATE.md, then post the comment yourself.
2. Optional: X-5 (build a package with an older fleetd on the builder VM, then C-1).
3. Optional: one run on x64 hardware with a TPM, for X-8 and before any guide change.

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
- QEMU VMs in `out/qemu/` (git-ignored): smoke, c1 to c4. c1 and c4 running, the rest shut down. Stop with
  `tools/qmp.sh <vm> '{"execute":"system_powerdown"}'`; delete the folders to reclaim about 75 GB.
- Cloudflare tunnel `fleet-lab-scep` (SCEP lab, not this project) now runs from `~/Documents/fleet-lab`.
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
