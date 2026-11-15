# Linux hosts

| Test needs | Use |
|---|---|
| A report, query, or package inventory | Docker: `testing/servicenow-itam-38864/scripts/run-sandbox-docker.sh [image ...]` (ubuntu:24.04, fedora:41, fresh container per run) |
| A reboot, desktop, or fleetd dialog | UTM VM, arm64, 4 GB, 4 cores, 25 GB |

Facts for the first evidence item: `hosts/host-facts.sh`.

## VM
- Ubuntu 24.04: server ISO with cloud-init autoinstall (serve it over HTTP, DMI serial `ds=nocloud-net;s=http://<bridge-ip>:<port>/`), then add a desktop. The desktop installer crashed.
- Fedora: netinst with a kickstart (`testing/linux-luks-54871/tests/gen-fedora-ks.py <dir>`). Deliver it on a disk labelled `OEMDRV`. Use `selinux --permissive` and ssh, because the guest agent doesn't work under SELinux.
- Display: use `virtio-gpu-pci`. Fedora needs `nomodeset console=tty0 console=ttyAMA0`.
- Installer ISO still attached: `testing/linux-luks-54871/tools/boot-vm.sh <vm>`.
- Commands: ssh, or `utmctl exec` (it exits 0 on errors, so read the output).
- Never screenshot installer pages that print secrets. One 4 GB VM at a time.

## fleetd
`fleetctl package --type=deb|rpm|pkg.tar.zst --arch=arm64 ...` ([fleet-and-packages.md](fleet-and-packages.md)).
Paths: `/opt/orbit/bin/orbit/linux/stable/orbit`, `/opt/orbit/identifier`.

## Ground truth
`testing/servicenow-itam-38864/scripts/gt-lib.sh` records each event (`GT_DIR`, `GT_HOST`), and `gt-linux.sh install|open|upgrade|uninstall|reinstall|facts` drives apt, dnf, or rpm-ostree. Compare the record with what Fleet reports. On Linux, DEB `list_changed` and RPM `install_time` move on each upgrade.

## Gotchas
- A red "Apply latest configuration to Fleet" run can be an empty enroll-secret repository secret.
- Scripts that source `ev.sh` lose their own `HERE`. Use another name.
- Test customer SQL with the `mysql` client, not only Go tests.
