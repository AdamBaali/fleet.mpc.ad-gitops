# X-8: BitLocker on before the reset

**Objective:** Turn on Fleet disk encryption, then C-1  
**Expected:** Reset completes; record any recovery key prompt  
**Run:** 2026-10-27T08:10:14Z to 2026-10-27T08:10:14Z

## Evidence

- `01-qemu-tpm-under-hvf.txt`: `grep -n -A3 "TPM device fails" ../_framework/vm/qemu-boot.sh`

## What happened

Not run. Fleet's BitLocker encryption needs a TPM, and upstream QEMU's arm TPM device crashes under HVF on this Mac
(`testing/_framework/vm/README.md`), so lab VMs have no TPM. Needs x64 hardware or an x64 VM with a TPM. The fleet 7
Windows BitLocker Lab is where such a host would go.

## Result: BLOCKED

Lab VMs have no TPM (QEMU arm TPM crashes under HVF), and Fleet BitLocker needs one; needs x64 hardware.
