# W-6: Package staged by a Fleet script in C:\Recovery\Customizations

- **Started:** 2026-10-26T19:45:17Z
- **Objective:** Host enrolled without a package (MSI-B installed directly); a Fleet script stages the package in C:\Recovery\Customizations; then doWipePersistProvisionedData. Does fleetd come back, re-enroll, and turn MDM on
- **Expected:** Back at the region screen with fleetd installed from the staged package; host re-enrolls; MDM On

## Steps and evidence
- `01-clone.txt`: `vm/clone.sh new ppkg-golden-oobe w6-stage && /usr/libexec/PlistBuddy -c 'Print :Information:UUID' $HOME/Librar`
- `02-region-screen.png` (window screenshot: UTM / w6-stage)
- `03-install-msi-b.txt`: `tools/vm-exec.sh w6-stage '$p = Start-Process msiexec.exe -ArgumentList "/i C:\Windows\Temp\fleet-osquery-arm6`
- `04-fleet-host-24.txt`: `fleetctl api /api/v1/fleet/hosts/24 2>/dev/null | python3 -c 'import json,sys; h=json.load(sys.stdin)["host"];`
- `05-stage-script.txt`: `cat scripts/stage-ppkg.ps1`
- `06-run-stage-script-via-fleet.txt`: `date -u +%FT%TZ; fleetctl run-script --host 329557D4-1408-4A41-8737-57A85722B6D4 --script-path scripts/stage-p`
- `07-before-vm.txt`: `tools/vm-exec.sh w6-stage 'Get-Service "Fleet osquery" | Format-Table Name,Status | Out-String; Get-ChildItem `
- `008-before-wipe.png` (window screenshot: UTM / w6-stage)
- `08-send-wipe.txt`: `date -u +%FT%TZ; fleetctl mdm run-command --hosts=329557D4-1408-4A41-8737-57A85722B6D4 --payload=payloads/doWi`
- `010-s195553.png` (window screenshot: UTM / w6-stage)
- `011-t1956.png` (window screenshot: UTM / w6-stage)
- `012-fleet-host-24-wipe-sent.jpg` (Fleet UI, Chrome)
- `013-s195623.png` (window screenshot: UTM / w6-stage)
- `014-t1956.png` (window screenshot: UTM / w6-stage)
- `015-s195653.png` (window screenshot: UTM / w6-stage)
- `016-s195723.png` (window screenshot: UTM / w6-stage)
- `017-t1957.png` (window screenshot: UTM / w6-stage)
- `018-s195754.png` (window screenshot: UTM / w6-stage)
- `019-t1958.png` (window screenshot: UTM / w6-stage)
- `020-s195824.png` (window screenshot: UTM / w6-stage)
- `021-s195854.png` (window screenshot: UTM / w6-stage)
- `022-t1959.png` (window screenshot: UTM / w6-stage)
- `023-s195924.png` (window screenshot: UTM / w6-stage)
- `024-t1959.png` (window screenshot: UTM / w6-stage)
- `025-s195954.png` (window screenshot: UTM / w6-stage)
- `026-s200025.png` (window screenshot: UTM / w6-stage)
- `027-t2000.png` (window screenshot: UTM / w6-stage)
- `028-s200055.png` (window screenshot: UTM / w6-stage)
- `029-t2001.png` (window screenshot: UTM / w6-stage)
- `030-s200125.png` (window screenshot: UTM / w6-stage)
- `031-s200155.png` (window screenshot: UTM / w6-stage)
- `032-t2002.png` (window screenshot: UTM / w6-stage)
- `033-s200226.png` (window screenshot: UTM / w6-stage)
- `034-t2002.png` (window screenshot: UTM / w6-stage)
- `035-s200256.png` (window screenshot: UTM / w6-stage)
- `036-s200326.png` (window screenshot: UTM / w6-stage)
- `037-t2003.png` (window screenshot: UTM / w6-stage)
- `038-s200356.png` (window screenshot: UTM / w6-stage)
- `039-t2004.png` (window screenshot: UTM / w6-stage)
- `040-s200426.png` (window screenshot: UTM / w6-stage)
- `041-s200457.png` (window screenshot: UTM / w6-stage)
- `042-t2005.png` (window screenshot: UTM / w6-stage)
- `043-s200527.png` (window screenshot: UTM / w6-stage)
- `044-t2005.png` (window screenshot: UTM / w6-stage)
- `045-s200557.png` (window screenshot: UTM / w6-stage)
- `046-s200627.png` (window screenshot: UTM / w6-stage)
- `047-t2006.png` (window screenshot: UTM / w6-stage)
- `048-s200657.png` (window screenshot: UTM / w6-stage)
- `049-t2007.png` (window screenshot: UTM / w6-stage)
- `050-s200728.png` (window screenshot: UTM / w6-stage)
- `051-s200758.png` (window screenshot: UTM / w6-stage)
- `052-t2008.png` (window screenshot: UTM / w6-stage)
- `053-s200828.png` (window screenshot: UTM / w6-stage)
- `054-t2008.png` (window screenshot: UTM / w6-stage)
- `055-s200858.png` (window screenshot: UTM / w6-stage)
- `056-s200929.png` (window screenshot: UTM / w6-stage)
- `057-t2009.png` (window screenshot: UTM / w6-stage)
- `058-s200959.png` (window screenshot: UTM / w6-stage)
- `059-t2010.png` (window screenshot: UTM / w6-stage)
- `060-s201029.png` (window screenshot: UTM / w6-stage)
- `061-s201059.png` (window screenshot: UTM / w6-stage)
- `062-t2011.png` (window screenshot: UTM / w6-stage)
- `063-s201130.png` (window screenshot: UTM / w6-stage)
- `064-t2011.png` (window screenshot: UTM / w6-stage)
- `065-s201200.png` (window screenshot: UTM / w6-stage)
- `066-s201230.png` (window screenshot: UTM / w6-stage)
- `067-t2012.png` (window screenshot: UTM / w6-stage)
- `068-s201300.png` (window screenshot: UTM / w6-stage)
- `069-t2013.png` (window screenshot: UTM / w6-stage)
- `070-s201330.png` (window screenshot: UTM / w6-stage)
- `071-s201401.png` (window screenshot: UTM / w6-stage)
- `072-t2014.png` (window screenshot: UTM / w6-stage)
- `073-s201431.png` (window screenshot: UTM / w6-stage)
- `074-t2014.png` (window screenshot: UTM / w6-stage)
- `075-s201501.png` (window screenshot: UTM / w6-stage)
- `076-t2015.png` (window screenshot: UTM / w6-stage)
- `077-t2016.png` (window screenshot: UTM / w6-stage)
- `078-t2017.png` (window screenshot: UTM / w6-stage)
- `079-after-two-restarts.png` (window screenshot: UTM / w6-stage)
- `080-t2017.png` (window screenshot: UTM / w6-stage)
- `081-t2018.png` (window screenshot: UTM / w6-stage)
- `082-t2019.png` (window screenshot: UTM / w6-stage)
- `083-iso-boot.png` (window screenshot: UTM / w6-stage)
- `084-t2019.png` (window screenshot: UTM / w6-stage)
- `085-advanced-options.png` (window screenshot: UTM / w6-stage)
- `086-winre-state.png` (window screenshot: UTM / w6-stage)
- `087-t2020.png` (window screenshot: UTM / w6-stage)
- `088-staged-package-after-reset.png` (window screenshot: UTM / w6-stage)
- `089-bcd-vsm-off.png` (window screenshot: UTM / w6-stage)
- `090-t2021.png` (window screenshot: UTM / w6-stage)
- `091-fleetd-in-reset-os.png` (window screenshot: UTM / w6-stage)
- `092-t2022.png` (window screenshot: UTM / w6-stage)

Reset ran 19:56 to about 20:05 (88% at 20:06). From about 20:11 the reset Windows hung at Start boot option, as in W-1. Booted the Windows ISO into WinRE (083 to 091). After the reset: C:\Recovery\Customizations\fleet-agent.ppkg (24,032,479 bytes) kept, plus InstallOrder.ini written at 20:04 by the reset, so push-button reset picked up the staged package. ProgramData\Microsoft\Provisioning holds no Fleet package (never applied at setup). Marker file gone (wiped). No Fleet osquery service yet in the reset OS (the package command runs at first boot). Lab fix attempt: bcdedit deletevalue {default} isolatedcontext, vsmlaunchtype Off, hypervisorlaunchtype Off (089). Rebooted 20:2x UTC.
- `093-s202219.png` (window screenshot: UTM / w6-stage)
- `094-t2022.png` (window screenshot: UTM / w6-stage)
- `095-s202240.png` (window screenshot: UTM / w6-stage)
- `096-t2022.png` (window screenshot: UTM / w6-stage)
- `097-s202300.png` (window screenshot: UTM / w6-stage)
- `098-t2023.png` (window screenshot: UTM / w6-stage)
- `099-s202320.png` (window screenshot: UTM / w6-stage)
- `100-s202340.png` (window screenshot: UTM / w6-stage)
- `101-t2023.png` (window screenshot: UTM / w6-stage)
- `102-t2023.png` (window screenshot: UTM / w6-stage)
- `103-s202400.png` (window screenshot: UTM / w6-stage)
- `104-s202421.png` (window screenshot: UTM / w6-stage)
- `105-t2024.png` (window screenshot: UTM / w6-stage)
- `106-t2024.png` (window screenshot: UTM / w6-stage)
- `107-s202441.png` (window screenshot: UTM / w6-stage)

With isolatedcontext removed and vsmlaunchtype and hypervisorlaunchtype Off, the reset Windows still hangs at Start boot option (screens from 20:23 identical to the earlier hang). Stopped at 20:25 UTC.

## Result: BLOCKED

Staging works: a Fleet script put the package in C:\Recovery\Customizations (exit 0, hash matches), doWipePersistProvisionedData wiped the device, kept the package, and the reset processed it (InstallOrder.ini written during the reset). Re-enrollment not observed: the reset Windows does not boot under UTM/QEMU on arm64 (same hang as W-1, not fixed by bcdboot or turning VSM off).

_Finished 2026-10-26T20:24:48Z_
