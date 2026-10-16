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

Not established whether the cause is the virtual TPM, the x64 emulation, or Duo requiring a signed health payload for Windows. Needs real Intel Windows hardware (or a Windows VM with a working TPM) to settle. Do not claim Windows Arm works with Duo in the guide.
