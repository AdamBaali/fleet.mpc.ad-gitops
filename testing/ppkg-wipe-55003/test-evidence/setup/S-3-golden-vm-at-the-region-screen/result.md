# S-3: Golden VM at the region screen

- **Started:** 2026-10-26T16:06:23Z
- **Objective:** Unattended Windows 11 Pro arm64 install that stops at the first setup screen
- **Expected:** VM boots to the region screen with no user account

## Steps and evidence
- `01-iso.txt`: `ls -la $HOME/Library/Parallels/Downloads/26100.4349.250607-1500.ge_release_svc_refresh_CLIENTCONSUMER_RET_A64F`
- `02-build.txt`: `vm/build-golden.sh ppkg-golden-oobe`

Stopped about a minute in, on Adam's call: use the latest Windows 11 release instead of 24H2 (26100.4349). The VM was deleted and the 24H2 ISO moved to the Trash. Rerun with the new ISO: ISO=<path> vm/build-golden.sh.

## Result: NOT-RUN

Stopped to switch to the latest Windows 11 arm64 ISO.

_Finished 2026-10-26T16:07:45Z_

Rerun 2026-10-26 evening with the current release from microsoft.com/software-download/windows11arm64 (Windows 11 2026 Update, 26H2).
- `03-iso-26h2.txt`: `ls -l $HOME/Downloads/win11-iso/Windows11_Client_arm64_en-us_26300_9457.iso; shasum -a 256 $HOME/Downloads/win`
- `04-build-26h2.txt`: `ISO=$HOME/Downloads/win11-iso/Windows11_Client_arm64_en-us_26300_9457.iso vm/build-golden.sh ppkg-golden-oobe`
- `05-installing.png` (window screenshot: UTM / ppkg-golden-oobe)
- `06-region-screen.png` (window screenshot: UTM / ppkg-golden-oobe)
- `07-hosts-line-and-idp-reachable.png` (window screenshot: UTM / ppkg-golden-oobe)

Golden VM: Windows 11 Pro 10.0.26300.9457 (26H2) arm64. At the region screen, added one hosts line (192.168.64.1 idp.ppkg.test) so clones reach the mock IdP, and checked the IdP answers. Shut down at the region screen with shutdown /s /t 0, as the ppkg guide says.

Finding: the golden VM has no network at the region screen. Windows has no in-box driver for UTM's virtio-net adapter on arm64, so idp.ppkg.test (and Fleet) can't be reached. The BitLocker lab installed UTM's Windows guest tools for this. Next: install utm-guest-tools 0.1.271 at the region screen (like an OEM image with its drivers), then shut down again.

## Result: PARTIAL

Golden VM stops at the region screen on Windows 11 26H2 Pro (build 26300.9457). No network yet: needs UTM's virtio-net driver from the guest tools.

_Finished 2026-10-26T17:29:12Z_
- `08-guest-tools-network.png` (window screenshot: UTM / ppkg-golden-oobe)
- `09-network-after-guest-tools.txt`: `tools/vm-exec.sh ppkg-golden-oobe 'Get-NetAdapter | Format-Table Name,InterfaceDescription,Status -AutoSize | `

Installed UTM guest tools 0.1.271 (only the .exe, repacked without the tools ISO's own Autounattend.xml) at the region screen. It added the VirtIO network driver and the QEMU guest agent, then restarted back to the region screen. Like an OEM image that ships with its drivers. The Windows and answer ISOs are detached from the golden VM so they can't affect later resets.

## Result: PASS

Golden VM: Windows 11 Pro 26H2 (26300.9457) at the region screen, no user account, network up, reaches Fleet and the mock IdP.

_Finished 2026-10-26T17:45:22Z_
