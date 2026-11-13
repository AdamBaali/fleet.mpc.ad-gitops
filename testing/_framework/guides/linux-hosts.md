# Linux hosts

How to get a Linux test host, install fleetd, run commands in it, and collect ground truth. Sources:
`testing/linux-luks-54871`, `testing/servicenow-itam-38864`, `testing/power-nap-46924` (package build).

The lab Mac runs arm64 guests, so every package is arm64. Docker containers are the quick option when a test needs no
display, no reboot, and no disk encryption.


## Pick the host type

| Test needs | Use |
|---|---|
| A report, query, or package inventory on a clean distro | Docker container (`servicenow-itam-38864/scripts/run-sandbox-docker.sh`) |
| A reboot, LUKS, a desktop session, fleetd dialogs | UTM VM: 4 GB RAM, 4 cores, 25 GB NVMe disk (`linux-luks-54871/VM_PLAN.md`) |
| A host of a distro Fleet doesn't list | Check the supported list first. Arch has no arm64 ISO (use archboot aarch64) and isn't supported for disk encryption |


## Docker sandbox

```bash
OSQ_DIR=<dir with the osquery tarball> testing/servicenow-itam-38864/scripts/run-sandbox-docker.sh [image ...]
```

It runs `ubuntu:24.04` and `fedora:41` with `--network host`, mounts the repo at `/repo`, and passes proxy variables and
`CA_BUNDLE`. Use a fresh container for each run so package history is clean.


## Build a VM

Ubuntu 24.04 (server ISO, cloud-init autoinstall, LVM on LUKS):
- Serve the autoinstall config over HTTP, bound to the bridge only. Set the DMI serial to
  `ds=nocloud-net;s=http://<bridge-ip>:<port>/`.
- The desktop autoinstall crashed after 28 minutes. Install the server image and add a desktop.
- Never screenshot the "Review your choices" page: it prints secrets.

Fedora (netinst, kickstart):
- `testing/linux-luks-54871/tests/gen-fedora-ks.py <serve-dir>` writes the kickstart. It uses
  `autopart --type=lvm --encrypted`, GNOME, GDM autologin, an ssh key, `qemu-guest-agent`, and a `%post` that installs the
  fleetd rpm. It writes secrets to `<serve-dir>/ks.cfg` at mode 600, outside the repo.
- The installer GRUB ignored letter keys, so deliver the kickstart on a disk labelled `OEMDRV` instead of `inst.ks=`.
- Set `selinux --permissive`, or the guest agent doesn't work. Use ssh for commands on Fedora.
- Pass plain-text passwords to the kickstart. macOS `openssl` and `python` can't make a sha512 hash, and an empty hash
  caused a failed install.
- The `%post` rpm download failed with curl 52 once. Install by hand if it does.

Display:
- Ubuntu desktop is black on `virtio-ramfb`. Use `virtio-gpu-pci`, with NVMe and virtio-net.
- Fedora shows "Display output is not active" after GRUB unless the kernel has `nomodeset console=tty0 console=ttyAMA0`.
- With an installer ISO still attached, `testing/linux-luks-54871/tools/boot-vm.sh <vm>` picks "Boot from next volume".

Run one 4 GB VM at a time on a shared Mac, keep 20 GB of disk free, and never quit UTM.


## Run commands in the guest

- ssh: `ssh -i secrets/lab_ed25519 lab@<ip> sudo ...` (needed on Fedora).
- UTM guest agent: `utmctl exec`. `utmctl` exits 0 even on errors, so read its output.
- Keys: `osascript -e 'tell application "UTM" to input keystroke (get virtual machine named "<vm>") text "..."'`. A `\n`
  doesn't press Return. Use set-1 scan codes `codes {28,156}`.
- Unattended reboot tests: `linux-luks-54871/tools/unlock-watch.sh <vm> --live` types the LUKS passphrase after each
  boot. A passphrase typed into GRUB opens its command line, so set `UNLOCK_DELAY` past the GRUB menu.
- Facts for the first evidence item: `testing/_framework/hosts/host-facts.sh`.


## Install fleetd

```bash
fleetctl package --type=deb|rpm|pkg.tar.zst --arch=arm64 --fleet-url="$FLEET_URL" \
  --enroll-secret="$SECRET" --fleet-desktop
```

Build one package per lab fleet: the enroll secret is inside it. Keep packages out of the repo, serve them from a local
HTTP server, and read secrets from a git-ignored `.env`. See [fleet-and-packages.md](fleet-and-packages.md).

Default paths: `/opt/orbit/bin/orbit/linux/stable/orbit`, `/opt/orbit/bin/osqueryd/linux/stable/osqueryd`, host token in
`/opt/orbit/identifier`.

On Wayland desktops (Arch, Omarchy), fleetd launches dialogs without `XDG_RUNTIME_DIR`, so `zenity` fails.


## Ground truth

Record what the host did, then compare it with what Fleet reported.

- `servicenow-itam-38864/scripts/gt-lib.sh` appends one row per event to `ground-truth/<host>.tsv`. Columns:
  `test_id host os app key version method event utc expected_publisher note`. Set `GT_DIR` and `GT_HOST`.
- `gt-linux.sh install|open|upgrade|uninstall|reinstall|facts` uses apt, dnf, or rpm-ostree, with `hello` as the package.
- On Linux, DEB `list_changed` and RPM `install_time` move on each upgrade. Use the exporter's `first_seen` for first
  installed.
- `host-local-check.sh` runs a report's SQL with fleetd's own osqueryd, with timings.


## Disk encryption (LUKS) tricks

- Trigger escrow: `POST /api/latest/fleet/device/<token>/mdm/linux/trigger_escrow`, with the token from
  `/opt/orbit/identifier`. 204 accepted, 409 already in flight. A request after a timed-out one returns 409 for minutes.
- Read the escrowed key: `GET /api/latest/fleet/hosts/<id>/encryption_key`. Never overwrite it with a wrong value
  (`linux-luks-54871/tests/restore-escrow.sh`).
- Which key opens which slot: `cryptsetup open --test-passphrase <dev> --key-file <f> -S <slot>`.
- Only `cryptsetup reencrypt` changes the master-key digest. `luksAddKey`, `luksChangeKey`, and `luksKillSlot` don't.
- Use scratch loop devices for destructive controls, never the root device.
- `linux-luks-54871/tools/luksdump.sh <vm>` prints a masked `luksDump`.
- Argon2 took 4 minutes on Ubuntu and 14 to 15 minutes on Fedora while the Mac was busy. The Fleet dialog needs an
  unlocked, visible desktop.


## Mistakes that cost hours

- A red "Apply latest configuration to Fleet" run can come from an empty enroll-secret repository secret. Check that
  before blaming your change.
- Scripts that source `ev.sh` lose their own `HERE`. Use `SDIR`.
- Run SQL meant for a customer with the `mysql` client, not only Go tests: the MySQL 8 default collation needs `SET NAMES`
  (`app-suffix-34088/tests/run-client-smoke.sh`).
- `curl_certificate` ignores the system proxy. A firewall that drops packets can stall each host.
