# Handoff: reset with a provisioning package

## State (2026-10-27)

- Done. Results in [RESULTS.md](RESULTS.md); draft issue comment in `drafts/ISSUE_UPDATE.md` (not posted).
- Fleet 10 "Windows Reset Lab" is at its GitOps settings (enroll secret and end user authentication checked through
  the API after X-3 and X-6).
- Fleet hosts left in fleet 10: 25, 26, 28, 30. Delete them before another run.
- All VMs are shut down: QEMU VMs in `out/qemu/` (git-ignored, about 75 GB), UTM VMs listed under Teardown.
- `ppkg-wipe-idp` (Docker, port 9080) is running. Check: `docker ps --filter name=ppkg-wipe-idp`.

## How to run a VM

`testing/_framework/vm/README.md` has the tools and rules. In this project:
- Base disk: the golden image in UTM's `ppkg-golden-oobe` bundle (Windows at the region screen, guest agent installed).
- `FG=1 tools/qemu-boot.sh <vm> <base.qcow2>` as a long-lived task; generalize through the guest agent.
- Plug in the package at the region screen with `tools/qmp.sh <vm> usb out/usb-pkg-<b|n>-plain.img true` and open it
  from Shift+F10.
- Watch a reset with `tools/qemu-watch.sh` and `tools/fleet-poll.sh`; check it with `queries/after-reset*.sql`.

## Teardown
- UTM: `ppkg-golden-oobe` (the QEMU base disk), `ppkg-golden-v0`, `ppkg-builder`, the USB images. QEMU: `out/qemu/`. Homebrew: `qemu`, `swtpm`.
- Local files: `out/` (MSIs, `.ppkg` files and USB images hold the enroll secret).
- Fleet: hosts in "Windows Reset Lab", then the fleet file. Rotate its enroll secret if a package left the Mac.
- Fleet: remove `mdm.end_user_authentication` from `default.yml` unless another lab uses it.
- GitHub: secret `FLEET_WINDOWS_RESET_LAB_ENROLL_SECRET` and its `workflow.yml` line.
- Mock IdP: see IDP_SETUP.md "Teardown".
