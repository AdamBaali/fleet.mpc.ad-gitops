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
