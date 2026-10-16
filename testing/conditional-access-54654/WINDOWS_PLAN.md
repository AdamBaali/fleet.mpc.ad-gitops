# Windows testing plan (resume here)

Everything else is done and paused. This is what remains for #54654. Use `tools/resume.sh` then `tools/status.sh`
first (brings the lab back up and checks it). Method: `testing/_framework/README.md`.

## What to bring
- An **x64 Windows 11** machine or VM (Duo Desktop for Windows is Intel only). A second Windows device is a bonus.
- It must reach this Mac on the network. Mac's current LAN address (check it, it can change): `ipconfig getifaddr en0`
  (192.168.4.24 on 2026-10-08). Ports used: 9031 and 9032 (PingFederate, already published on all interfaces),
  8443 (Duo demo; `duo/start-demo.sh` binds the VM bridge only, so for a LAN machine start it on the LAN address).
- Tell Claude: the machine's name, how you reach it (RDP, UTM, console) and the Mac's LAN IP.


## Decision (2026-10-16): x64 hardware is not required to start
Duo's docs say Duo Desktop for Windows supports Intel processors only. Windows 11 on Arm runs x64 apps under emulation, the same way Duo Desktop ran on the Linux ARM VM under QEMU. So:
1. **Start on a Windows 11 ARM VM** (the 42318 lab already built one: `fleet-42318-lab/vm/build-vm.sh`, same Microsoft Arm64 ISO; or reuse its tablet clone). The cert profiles, MachineGuid report, export and sync, and browser sign-in tests (P-1, P-2, P-7 to P-14, D-2, D-3, D-4, D-11) need no Duo Desktop and run natively on Arm.
2. **Try the x64 Duo Desktop installer on that VM** (D-1, D-5, D-8, L-1). If it installs and reports a device ID that matches MachineGuid, record it as PASS under emulation, as with Linux.
3. **Only ask for an x64 machine if step 2 fails.** Then say in the guide that Duo Desktop for Windows needs Intel hardware, and name the tests that stayed untested. That is an honest, acceptable limit for the guide owners; it is not acceptable to leave it unstated.
Fleet side: reuse the 42318 host record by moving host 16 to the Ping Duo Lab fleet, or enroll a new VM with `out/fleet-osquery-arm64.msi` (`tools/build-windows-msi.sh arm64`).

## Steps
1. **Build the agent:** `tools/build-windows-msi.sh amd64` -> `out/fleet-osquery.msi` (secret never printed). Copy to Windows.
2. **Enroll in the Ping Duo Lab fleet:** run the MSI as administrator. Windows MDM turns on after a user signs in to the
   host (see Fleet's Windows MDM guide). Check the host appears in the fleet and shows MDM "On".
3. **Name resolution:** as administrator, `Add-Content C:\Windows\System32\drivers\etc\hosts "<Mac LAN IP> ping.lab"`.
4. **Trust and certificate:** the `Lab CA root certificate` profile (`lib/windows/configuration-profiles/lab-ca-root-trust.xml`)
   and `Lab CA client certificate` (`lab-ca-scep-user.xml`, `SubjectName` = `CN=$FLEET_VAR_HOST_UUID,OU=$FLEET_VAR_CERTIFICATE_RENEWAL_ID`)
   should arrive. Verify: `certutil -user -store My` shows a certificate whose CN is the host UUID; `Get-ChildItem Cert:\CurrentUser\My`.
5. **Duo Desktop:** the Windows policy "Duo Desktop installed (Windows)" installs it. Confirm it runs.
6. **MachineGuid report:** the report `windows-machine-guid` (interval 300 s, data kept). Note its ID and set it in
   `fleets/ping-duo-lab/duo-sync/export-fleet-hosts-for-duo.sh` (the lab copy in `duo/run/export-guide.sh` uses ID 69; re-check).
7. **Duo sync:** run `duo/sync.sh`; the Windows list should upload (`windows: N synced` in `duo/sync.log`). Activate the Windows
   integration for the group `fleet-lab` in the Duo Admin Panel (Adam; sign-in needed).
8. **Browser sign-in:** Chrome and Edge with the `AutoSelectCertificateForUrls` policy; open
   `https://ping.lab:9031/as/authorization.oauth2?client_id=labclient&response_type=code&redirect_uri=http%3A%2F%2Flocalhost%3A8765%2Fcallback&state=win`.
   Expect an authorization code in the URL (the redirect to localhost:8765 will show a connection error; the URL has the code).
9. **Decisions:** flip the critical policy `CA test - flag file absent (Windows)` (create `C:\fleet-ca-test`), Refetch, confirm denial, remove, confirm recovery.
10. **Duo sign-in:** demo app (`https://ping.lab:8443/`), user `lab-test`, trusted via Duo Desktop; then remove the host from the Duo list (as D-8) and confirm the block.
11. **D-11 `report_cap`:** lower it on the lab Fleet temporarily (for example 1), confirm Windows hosts past the cap drop out of the list, restore it.
12. **Finish:** `bin/build-evidence-index.py` (see the framework), update `ISSUE_UPDATE.md`, then the draft PR.

## Test IDs for Windows (add to `test-evidence/windows/`)
P-1/P-2 certificate, P-7 to P-13 sign-in decisions, P-14 Chrome/Edge auto-select, P-15 renewal (short-lived cert), D-1 Duo Desktop, D-2 MachineGuid report,
D-3/D-4 export and sync, D-5/D-8 trusted and blocked, D-11 report cap, L-1 device ID (MachineGuid).

## Known gotchas
- Windows only accepts letters, numbers and `' ( ) + , - . / : = ?` in the SCEP challenge.
- Fleet's Windows SCEP example uses 1024-bit keys and SHA-1; the lab CA needs 2048-bit and SHA-2 (profile already fixed).
- `CAThumbprint` is the SHA-1 of the CA certificate (the Okta page calls it SHA-256).
- Window-only screenshots; mask sign-in codes. Never print the enroll secret or tokens.
