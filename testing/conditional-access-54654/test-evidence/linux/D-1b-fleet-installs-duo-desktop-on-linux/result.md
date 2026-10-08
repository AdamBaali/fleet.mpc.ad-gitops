# D-1b: Fleet installs Duo Desktop on Linux through a policy

- **Objective:** a Linux host without Duo Desktop gets it from Fleet through policy automation, as for macOS and Windows.
- **Expected:** the policy fails, Fleet installs the custom package, the policy passes.
- `01-timeline.txt`: timestamps for each step.

## Result: PASS

Fleet installed the x86-64 .deb (`duo-desktop-latest.amd64.deb`) in about 1 minute 45 seconds and the service came up active. Lab note: the VM is ARM, so the package runs under x86 emulation, which was set up earlier (`/etc/systemd/system/duo-desktop.service.d/emulation.conf` survives the reinstall).
Finding: the policy query must not match a package that was removed but kept its config (`rc`). Use `status = 'install ok installed'`.
