# S-3: Golden VM at the region screen

- **Started:** 2026-10-26T17:05:35Z
- **Objective:** Unattended Windows 11 Pro arm64 install that stops at the first setup screen
- **Expected:** VM boots to the region screen with no user account

## Steps and evidence
- `03-iso-26h2.txt`: `ls -l $HOME/Downloads/win11-iso/Windows11_Client_arm64_en-us_26300_9457.iso; shasum -a 256 $HOME/Downloads/win`
- `04-build-26h2.txt`: `ISO=$HOME/Downloads/win11-iso/Windows11_Client_arm64_en-us_26300_9457.iso vm/build-golden.sh ppkg-golden-oobe`
- `05-installing.png` (window screenshot: UTM / ppkg-golden-oobe)
- `06-region-screen.png` (window screenshot: UTM / ppkg-golden-oobe)
- `07-hosts-line-and-idp-reachable.png` (window screenshot: UTM / ppkg-golden-oobe)

Golden VM: Windows 11 Pro 10.0.26300.9457 (26H2) arm64. At the region screen, added one hosts line (192.168.64.1 idp.ppkg.test) so clones reach the mock IdP, and checked the IdP answers. Shut down at the region screen with shutdown /s /t 0, as the ppkg guide says.

- `08-guest-tools-network.png` (window screenshot: UTM / ppkg-golden-oobe)
- `09-network-after-guest-tools.txt`: `tools/vm-exec.sh ppkg-golden-oobe 'Get-NetAdapter | Format-Table Name,InterfaceDescription,Status -AutoSize | `

Installed UTM guest tools 0.1.271 (only the .exe, repacked without the tools ISO's own Autounattend.xml) at the region screen. It added the VirtIO network driver and the QEMU guest agent, then restarted back to the region screen. Like an OEM image that ships with its drivers. The Windows and answer ISOs are detached from the golden VM so they can't affect later resets.

## Result: PASS

Golden VM: Windows 11 Pro 26H2 (26300.9457) at the region screen, no user account, network up, reaches Fleet and the mock IdP.

_Finished 2026-10-26T17:45:22Z_
