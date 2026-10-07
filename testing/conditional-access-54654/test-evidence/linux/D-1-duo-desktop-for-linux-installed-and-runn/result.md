# D-1: Duo Desktop for Linux installed and running

- **Started:** 2026-10-07T18:43:04Z
- **Objective:** Duo Desktop 4.7.0 runs on the Linux host. (Lab: x86-64 package under user-mode emulation on an ARM VM; Duo documents ARM Linux as unsupported. Installed by hand with dpkg, not by a Fleet custom package.)
- **Expected:** The duo-desktop service is active and listening on 53100 (HTTPS) and 53106 (HTTP).

## Steps and evidence
- `01-package-and-service.txt` (VM): `dpkg -l duo-desktop | tail -1 | cut -c1-90; systemctl is-active duo-desktop; systemctl show duo-desktop -p NRe`
- `02-emulation-dropin.txt` (VM): `cat /etc/systemd/system/duo-desktop.service.d/emulation.conf; echo; /usr/local/bin/qemu-x86_64-10 --version | `
- `03-https-answers.txt` (VM): `curl -sk -m 10 -o /dev/null -w 'https://localhost:53100/ -> %{http_code}\n' https://localhost:53100/; curl -s `
- `04-duo-desktop-log.txt` (VM): `tail -14 /var/log/duo-desktop/duo-desktop.log | cut -c1-230`

## Result: **PARTIAL**

Duo Desktop 4.7.0 (amd64 package from Duo's download link) is installed and its service is active, answering on HTTPS 53100 and HTTP 53106. It needed lab workarounds because the VM is ARM: amd64 multiarch, x86 libraries, QEMU 10 user-mode emulation, DOTNET_EnableWriteXorExecute=0. A Fleet-driven install of the custom package and a real x86-64 host were not tested.

_Finished 2026-10-07T18:43:07Z_

Terminal screenshot in the VM (added 2026-10-08)
- `05-terminal-duo-desktop-running.png` (VM screenshot)
