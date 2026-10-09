# S-8: first boot after install

- **Date:** 2026-10-08
- **Objective:** Boot the installed encrypted Ubuntu, reach the disk unlock prompt, and the desktop.
- **Expected:** An unlock prompt, then the login or desktop.

## Steps and evidence
- `01`-`10`: every start of the VM showed a black "Display output is not active." screen. Tried: Enter, force stop and start, rebuilding the VM around the same disk with `virtio-gpu-pci` and `virtio-ramfb` display devices, fresh UEFI settings. QEMU kept running at low CPU. The serial console gave nothing. No DHCP lease or guest agent appeared, so the guest never got past the unlock prompt (if it reached it).
- Theory (not confirmed): the graphical unlock prompt doesn't paint on this virtual display, so the VM waits blind for the passphrase. A first autoinstall server VM showed its text unlock prompt on the same display, so the display device itself works.

## Result: BLOCKED

Next: boot the installer ISO's "Try Ubuntu" session to inspect the disk, or use a VM created with UTM's own wizard (which the earlier AppleScript-built VMs differ from), or install the server image with encrypted LVM.
