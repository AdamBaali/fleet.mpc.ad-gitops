# Windows results (Windows 11 Arm64 VM, 2026-10-16)

Host: UTM VM on an Apple silicon Mac, Windows 11 Pro 26300 (arm64), virtual TPM 2.0, enrolled in the Ping Duo Lab fleet with Windows MDM. Duo Desktop for Windows is documented as Intel-only; here the x64 installer runs under Windows' x64 emulation. Treat Duo results as an emulation experiment, not support.

| Test | Result | Evidence |
| --- | --- | --- |
| P-1/P-2 certificate profile | PASS after a profile fix (below) | User store holds a certificate with CN = host UUID, OU = renewal ID, issuer Fleet Lab CA Intermediate CA, private key present |
| Root trust profile | PASS after fix | `Verified`; the lab CA root is in `LocalMachine\Root` |
| D-1 Duo Desktop installed by policy | PASS (emulated) | Fleet installed it, policy passes; services `DuoCryptoService`, `DuoDesktopUpdateService`, `DuoTrustedPeerMessageBrokerService` run; Duo Desktop 7.22.0 logs "Started HTTPS server on port 53100" and HTTP 53106; no crash, no TPM error, no workaround needed (Linux under QEMU needed `DOTNET_EnableWriteXorExecute=0`) |
| D-2 MachineGuid report | PASS | Report 69 returns `machine_guid` for the host; equals `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid` |
| D-3/D-4 export and sync | PASS | `windows: 1 synced` in the lab sync log |
| P-14 Edge sign-in, certificate auto-selected | PASS | [screenshot](P-14-edge-auto-select-sign-in/01-edge-callback-with-code.png): no picker, authorization code returned (code masked) |

## Guide findings from Windows
1. **Root CA profile node name.** `./Device/Vendor/MSFT/RootCATrustedCertificates/Root/<name>/EncodedCertificate` failed with status 500 when `<name>` was a free-text label (`FleetLabCARoot`). Naming the node by the certificate's SHA-1 thumbprint (uppercase hex) made it `Verified`. Fleet's Wi-Fi guide uses a free-text name (`<YOURCA>`); Microsoft's CSP defines the node as the certificate hash. Not yet re-tested with a second CA.
2. **Chrome and Edge on Windows.** The guide says only "deploy the policy". Writing `HKLM\SOFTWARE\Policies\Microsoft\Edge\AutoSelectCertificateForUrls\1` (and `Google\Chrome`) with the JSON pattern for port 9032 worked (`lab-setup/windows-vm/set-browser-autoselect.ps1`). Not yet delivered as a Fleet script or profile.
3. **Duo Desktop on Windows Arm** installs and runs under emulation, though Duo lists Intel only.
