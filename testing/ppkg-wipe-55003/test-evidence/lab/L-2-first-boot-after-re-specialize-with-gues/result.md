# L-2: First boot after re-specialize with guest-tools drivers removed

- **Started:** 2026-10-26T21:22:42Z
- **Objective:** Find whether UTM guest-tools drivers cause the first-boot hang after sysprep generalize and resets
- **Expected:** With only NetKVM and vioserial left, a generalized clone boots to the region screen

## Steps and evidence
- `01-clone.txt`: `vm/clone.sh new ppkg-golden-oobe l2-strip`
- `02-drivers-before.txt`: `tools/vm-exec.sh l2-strip 'pnputil /enum-drivers | Out-String -Width 200; Get-Package -ErrorAction SilentlyCon`
- `03-remove-drivers.txt`: `tools/vm-exec.sh l2-strip '$keep = "netkvm.inf","vioser.inf"; $d = Get-WindowsDriver -Online | Where-Object { `
- `004-after-remove.png` (window screenshot: UTM / l2-strip)
- `005-iso-boot.png` (window screenshot: UTM / l2-strip)

Removing the Red Hat drivers with pnputil /uninstall made Windows restart itself, and that warm restart hung at Start boot option (004), agent never answered. A hard power-off and cold start then booted normally to the region screen (005). So the hang is not caused by a missing driver on a cold boot.
- `04-drivers-after.txt`: `tools/vm-exec.sh l2-strip 'Get-WindowsDriver -Online | Where-Object ProviderName -eq "Red Hat, Inc." | ForEach`
- `007-during-remove.png` (window screenshot: UTM / l2-strip)
- `008-removal-check.png` (window screenshot: UTM / l2-strip)

Root cause found instead: utmapp/UTM#7648 (open, UTM 4.x and 5.x; lab runs UTM 4.7.5). After a guest-initiated restart the QEMU virt/edk2 firmware sometimes spins before boot device selection: Start boot option on screen, one vCPU pegged, disk idle; a forced power-off and cold start always recovers. Every hang in this project matches (resets, sysprep generalize clone, driver removal restarts). The driver hypothesis is refuted: the hang hit warm restarts with drivers present and absent, and a cold start booted with them removed. Windows resets and specialize restart several times, so each restart can hang; v1 waited or repaired instead of cycling. Workaround: tools/hang-watchdog.sh power-cycles a VM when its frame is unchanged for 90 s with QEMU above 90% CPU.


Reopened 22:40 UTC: cold boots of generalized clones also hang, so #7648 (warm reboot) is not the whole story. Two issues: #7648 on ordinary warm restarts (cold start fixes), and the first boot that re-runs specialize after generalize or reset (cold start does not fix). The fresh ISO install ran specialize fine before the guest tools existed. Experiment: arm A strips guest-tools drivers except NetKVM and vioserial then generalizes; arm B is a fresh ISO install with no guest tools, generalized at the region screen.
