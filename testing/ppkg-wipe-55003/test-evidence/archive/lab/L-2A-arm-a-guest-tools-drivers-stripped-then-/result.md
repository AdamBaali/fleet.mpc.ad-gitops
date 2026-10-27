# L-2A: Arm A: guest-tools drivers stripped, then generalize

- **Started:** 2026-10-26T22:38:07Z
- **Objective:** Remove UTM guest-tools drivers except NetKVM and vioserial, generalize, cold-boot a clone
- **Expected:** Clone boots (DHCP lease)

## Steps and evidence
- `01-clone.txt`: `vm/clone.sh new ppkg-golden-oobe a-strip`
- `02-drivers-left.txt`: `tools/vm-exec.sh a-strip 'Get-Content C:\Windows\Temp\rm.log; "--- left"; Get-WindowsDriver -Online | Where-Ob`
- `03-sysprep.txt`: `tools/vm-exec.sh a-strip 'Start-Process C:\Windows\System32\Sysprep\sysprep.exe -ArgumentList "/generalize /oo`
- `04-clone-boot.txt`: `vm/clone.sh new a-strip a-test >/dev/null && open -g -a UTM $HOME/Library/Containers/com.utmapp.UTM/Data/Docum`
- `005-state.png` (window screenshot: UTM / a-strip)

## Result: INFO

Invalid as designed: removing guest-tools drivers from the running image left it unbootable (Your device ran into a problem and could not be repaired, 005) before sysprep ran. Arm B (image that never had the tools) is the deciding test.

_Finished 2026-10-26T23:03:00Z_
