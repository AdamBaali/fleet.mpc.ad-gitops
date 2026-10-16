# D-5 Windows: Duo sign-in (Arm VM, Duo Desktop under emulation)

**Result: BLOCKED (not a pass).** Duo reaches Duo Desktop but does not trust the device.

Setup: Windows integration "Generic with Duo Desktop 1" set to *Test with a group* (`fleet-lab`); list uploaded with the host's MachineGuid (`a00c4070-...`, equal to `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid`; the page Duo documents for Windows says MachineGuid).

What happened, in order:
1. Duo Universal Prompt asks Edge for the "access other apps and services on this device" (local network) permission, as on macOS and Linux.
2. Edge asks "This site is trying to open Duo Desktop" (Windows protocol handler). New for the guide ([screenshot](01-edge-asks-to-open-duo-desktop.png)).
3. First attempt: "Install Duo Desktop. Your organization requires you to install Duo Desktop before logging in" ([screenshot](02-install-duo-desktop-screen.png)).
4. After restarting Duo's services and Duo Desktop and reloading: "Device not allowed. Your organization requires you to use a trusted device" ([screenshot](03-device-not-allowed.png)). Duo's endpoint page lists the device as Windows, Edge, **Trusted Endpoint: Unknown**.

Duo Desktop log (7.22.0): the browser reaches `/alive` and `/report` (204), then every health check logs `Failed to sign health payload ... Error loading computer key;error loading dakey`. The same message appeared on Linux, where the device was still trusted. Duo Desktop uses raw TPM access (Tpm2Lib: persistent signing key) rather than CNG.

Checked and ruled out: device ID mismatch (equal), Duo Desktop not running (3 services and the app run; HTTPS 53100 and HTTP 53106 answer), no TPM (TPM 2.0 present, WMI ready/enabled/owned, a CNG key can be created in the Platform Crypto Provider). Open: the Windows TPM driver logs event 15 ("non-recoverable error in the TPM hardware") every ~9 minutes and `Get-Tpm` fails with 0x80284001; UTM's swtpm may not support what Duo's TPM key creation needs.

## Root cause: NOT established (correction, 2026-10-16)
An earlier version of this note said UTM's virtual TPM cannot create ECC keys. That is **not supported by the evidence**. A hand-built `CreatePrimary` ECC template (scripts in `lab-setup/windows-vm/tpm-probe/`) failed with `TPM_RC_CURVE`, but it failed identically on a second, different TPM (Homebrew swtpm 0.10.2 / libtpms 0.10.2), and on that TPM Windows' own Platform Crypto Provider creates ECDSA P-256 and P-384 keys without error. So the probe template was wrong, or both TPMs share a limit the provider route avoids. The probe says nothing reliable about Duo's `dakey`.

What is established: Duo Desktop runs, answers the browser, logs `error loading dakey`, and Duo shows Trusted Endpoint: Unknown on the UTM TPM. A retest on a standalone QEMU VM with swtpm 0.10 follows below.

## Retest on a second TPM (2026-10-16, later): inconclusive
To rule out UTM's virtual TPM, the VM disk was run in standalone Homebrew QEMU 11.1 with Homebrew swtpm 0.10.2 (`lab-setup/windows-vm/standalone-qemu/`). UTM's sandbox cannot connect to an external swtpm socket, and Homebrew's QEMU has no CRB TPM device for the Arm `virt` machine, so the TIS device was used. Windows booted and the guest agent worked, and Windows' own provider created ECDSA P-256/P-384 keys in that TPM. But the guest became very slow and Edge reported "This page isn't responding" before the Duo sign-in could be repeated, and Duo Desktop's first health check never finished. So this retest neither confirms nor rules out the TPM as the cause.

**Conclusion for the guide:** Duo Desktop for Windows is documented as Intel-only. On Windows 11 Arm under UTM, Duo Desktop installs and runs but the device is not trusted (`error loading dakey`). Treat Windows Duo (D-5, D-8) as untested; it needs Intel Windows hardware.
