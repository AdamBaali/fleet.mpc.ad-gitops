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
