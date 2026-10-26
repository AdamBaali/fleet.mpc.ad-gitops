# Notes: desk findings, risks, lab versus production

Code links are at `fleet-v4.93.2`. Re-check at the lab's version (S-0).


## Desk findings (to confirm in the lab)

**D-1. A wiped host that Fleet still knows skips the IdP, even without the bypass flag.**
`server/service/orbit.go` (enroll, about line 330): when end user authentication is required and no IdP account is
linked, Fleet calls `HostPreviouslyOrbitEnrolled`. If a host with the same hardware UUID or serial already has an orbit
node key, Fleet logs `allowing re-enrollment without end-user authentication` and lets it in
(`server/datastore/mysql/hosts.go`, `HostPreviouslyOrbitEnrolled`). The Windows and Linux setup experience guide says the
same: "When wiping and re-enrolling a host, delete the host from Fleet as well." So after a reset the quote in the thread
("won't communicate back until the end user authenticates") likely applies only when the host was deleted. W-2 and W-3
test this.

**D-2. The two Fleet docs disagree on the bypass setting.**
`articles/windows-linux-setup-experience.md` ("Skip authentication") says `--bypass-end-user-auth` "only works if"
`mdm.allow_orbit_end_user_auth_bypass` "is set to false". The server configuration reference and the code say the
opposite: the default `true` lets bypass hosts enroll, and `false` blocks them (`server/service/orbit.go`, the
`AllowOrbitEndUserAuthBypass && !clientSupportsEUA` case). E-1 runs with the default and should confirm the code.
Docs fix to propose after E-1.

**D-3. An MSI built without the bypass flag still enrolls when the server allows bypass, if it is old.**
The server lets in any client that doesn't advertise the end user auth capability. fleetd 1.60.0 and later advertise it
unless built with `--bypass-end-user-auth` (`orbit/cmd/orbit/orbit.go`, `bypassEndUserAuth`). The package reinstalls the
fleetd version it was built with, then fleetd updates itself. Use the current fleetd in both MSIs so E-2 tests
"no bypass".

**D-4. Microsoft names a different folder than the thread.**
The RemoteWipe CSP says `doWipePersistProvisionedData` keeps packages in `%SystemDrive%\ProgramData\Microsoft\Provisioning`.
The thread says `C:\Recovery\Customizations`, which is the push-button reset folder (used by any reset, per Microsoft's
"Recovery components" page). These are two separate paths: W-1 tests the first, W-7 the second.

**D-5. Fleet's built-in wipe offers `doWipe` and `doWipeProtected` only.**
`server/fleet/windows_mdm.go` (`MDMWindowsWipeType`). The persist variants go out as custom commands. Payloads are in
Fleet's MDM command library (`docs/mdm-commands.yml`).

**D-6. Adding `org_settings.mdm` to `default.yml` changes nothing else.**
GitOps builds the `mdm` map whether or not the YAML has one, and fills the same defaults for missing keys either way
(`server/service/client.go`, "Ensure mdm config exists", about line 2452). So the new block only adds the IdP. The
dry run in S-2 confirms it.


## Risks for the lab

- **Local account at setup.** Windows 11 26H2 Pro may push a Microsoft account. Options, in order: Shift+F10
  `start ms-cxh:localonly`, Windows 11 Enterprise evaluation media, or an answer file `oobeSystem` pass (but that skips
  the region screen, so only for the builder VM). Record what worked.
- **USB in UTM.** If the region screen doesn't see the package on a UTM removable drive, use the Shift+F10 fallback in
  S-7 and say so in the results. It is close to, but not the same as, inserting a USB drive.
- **WinRE in the VM.** Reset needs the recovery environment. S-3b checks it. Without it, `doWipe` variants fail and only
  the cloud variant might work.
- **Encrypted packages after a reset.** Unknown whether Windows asks for the package password again when it re-applies a
  persisted package. If it does, unattended reset needs an unencrypted package, which exposes the enroll secret. Watch in W-1.
- **Arm64 cloud image.** W-5 downloads an arm64 image. Note size and time.
- **Global IdP setting.** Adding `mdm.end_user_authentication` to `default.yml` changes "All fleets" settings. Only fleets
  with `enable_end_user_authentication` use it. S-0 checks that none do today.


## Lab versus production

- VM with Ethernet. Real laptops often have only Wi-Fi, so they reach Fleet only after the end user picks a network.
- arm64 VM. Most customer laptops are x64. Run W-1 once on a physical x64 laptop before changing any guide.
- No BitLocker during the reset. Fleet-managed laptops usually have BitLocker on.
- One hosts file line in the VM (`idp.ppkg.test`) so it can reach the mock IdP. Real IdPs are public. A reset removes the line, so it is added again at the region screen.
- UTM keeps the SMBIOS UUID and serial across resets, as real hardware does. Fleet matches hosts on these.


## Security notes for the write-up

- The package and the persisted copy hold the enroll secret. E-3 records who can read them.
- A package in `C:\Recovery\Customizations` (W-7, P-1) is readable by local admins.


## Not tested

See "Out of scope" in [TEST_PLAN.md](TEST_PLAN.md).
