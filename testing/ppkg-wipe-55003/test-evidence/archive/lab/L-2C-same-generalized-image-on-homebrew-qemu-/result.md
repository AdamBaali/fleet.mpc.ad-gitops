# L-2C: Same generalized image on Homebrew QEMU 11.1.2 and edk2

- **Started:** 2026-10-26T23:53:46Z
- **Objective:** Boot the golden image under qemu-system-aarch64 11.1.2 with Homebrew edk2 and an empty NVRAM (tools/qemu-boot.sh), run sysprep /generalize /oobe /reboot through the guest agent
- **Expected:** Windows comes back to the region screen after the warm reboot

## Steps and evidence
- `05-sysprep-state.txt`: `tools/qga.sh smoke 'Get-ItemProperty HKLM:\SYSTEM\Setup | Select SystemSetupInProgress,OOBEInProgress | fl; Ge`

## Result: PASS

Generalized image boots on Homebrew QEMU 11.1.2 with no hang: guest agent answered with a new hostname 60 s after sysprep's reboot, region screen shown. The hang is in UTM 4.7.5's QEMU/edk2, not Windows.

_Finished 2026-10-26T23:53:56Z_
