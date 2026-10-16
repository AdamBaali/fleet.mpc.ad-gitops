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
| P-9 failing critical policy denies sign-in | PASS | Created `C:\fleet-ca-test`, refetch: `failing_critical_policies_count` 1; sign-in returned `error_description=Host is not in Fleet or is failing a critical policy` ([screenshot](P-9-edge-failing-critical-policy-denied/01-denied.png)) |
| P-10 recovers after the fix | PASS | Removed the file, refetch: count 0 after 83 s; sign-in returned a code ([screenshot](P-10-edge-recovers-after-fix/01-signed-in-again.png), code masked) |
| P-7/P-8 non-critical failing policy does not block | PASS | "CA test - always fails (non-critical)" was failing during P-14 and P-10 and sign-in still worked |

## Guide findings from Windows
1. **Root CA profile node name.** `./Device/Vendor/MSFT/RootCATrustedCertificates/Root/<name>/EncodedCertificate` failed with status 500 when `<name>` was a free-text label (`FleetLabCARoot`). Naming the node by the certificate's SHA-1 thumbprint (uppercase hex) made it `Verified`. Fleet's Wi-Fi guide uses a free-text name (`<YOURCA>`); Microsoft's CSP defines the node as the certificate hash. Not yet re-tested with a second CA.
2. **Chrome and Edge on Windows.** The guide says only "deploy the policy". Writing `HKLM\SOFTWARE\Policies\Microsoft\Edge\AutoSelectCertificateForUrls\1` (and `Google\Chrome`) with the JSON pattern for port 9032 worked (`lab-setup/windows-vm/set-browser-autoselect.ps1`). Not yet delivered as a Fleet script or profile.
3. **Duo Desktop on Windows Arm** installs and runs under emulation (Duo lists Intel only). The device is trusted only when the VM has no TPM; with UTM's virtual TPM it logs `error loading dakey` and is not trusted. Emulation result, not a support claim.
4. **Windows sign-in prompts:** besides the local network permission, Edge asks "This site is trying to open Duo Desktop" (protocol handler) on the first Duo sign-in.

| D-5 Duo sign-in | PASS without a TPM in the VM; fails with UTM's virtual TPM | [notes](D-5-duo-sign-in-blocked-on-arm/result.md): second-factor screen reached and Duo Admin lists the device as Trusted Endpoint: Yes; with the TPM present Duo Desktop logs `error loading dakey` and Duo says "Device not allowed" |

## Not done on Windows yet
- D-8 (blocked when removed from the list) was not run on Windows.
- D-11 `report_cap` (needs at least two Windows hosts in the fleet; one host cannot show hosts dropping out).
- P-15 renewal, Chrome (Edge only), Fleet-delivered auto-select, second CA for the root-trust node name.
