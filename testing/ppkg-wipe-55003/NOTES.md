# Notes: desk findings and lab versus production

Desk findings from Fleet code and Microsoft docs, made before the lab runs and checked by them. Code links are at
`fleet-v4.93.2`; the files cited don't change between 4.93.0 and 4.93.2 (S-0).


## Desk findings

**D-1. A wiped host that Fleet still knows skips the IdP, even without the bypass flag.**
`server/service/orbit.go` (enroll, about line 330): when end user authentication is required and no IdP account is
linked, Fleet calls `HostPreviouslyOrbitEnrolled`. If a host with the same hardware UUID or serial already has an orbit
node key, Fleet logs `allowing re-enrollment without end-user authentication` and lets it in
(`server/datastore/mysql/hosts.go`, `HostPreviouslyOrbitEnrolled`). The Windows and Linux setup experience guide says the
same: "When wiping and re-enrolling a host, delete the host from Fleet as well." So after a reset the quote in the thread
("won't communicate back until the end user authenticates") applies only when the host was deleted. Confirmed by C-2
and C-3.

**D-2. The two Fleet docs disagree on the bypass setting.**
`articles/windows-linux-setup-experience.md` ("Skip authentication") says `--bypass-end-user-auth` "only works if"
`mdm.allow_orbit_end_user_auth_bypass` "is set to false". The server configuration reference and the code say the
opposite: the default `true` lets bypass hosts enroll, and `false` blocks them (`server/service/orbit.go`, the
`AllowOrbitEndUserAuthBypass && !clientSupportsEUA` case). E-1b ran with the default and confirmed the code. Docs fix to propose.

**D-3. An MSI built without the bypass flag still enrolls when the server allows bypass, if it is old.**
The server lets in any client that doesn't advertise the end user auth capability. fleetd 1.60.0 and later advertise it
unless built with `--bypass-end-user-auth` (`orbit/cmd/orbit/orbit.go`, `bypassEndUserAuth`). The package reinstalls the
fleetd version it was built with, then fleetd updates itself. Both MSIs use fleetd 1.62.1, so E-2 tests
"no bypass".

**D-4. Microsoft names a different folder than the thread.**
The RemoteWipe CSP says `doWipePersistProvisionedData` keeps packages in `%SystemDrive%\ProgramData\Microsoft\Provisioning`.
The thread says `C:\Recovery\Customizations`, which is the push-button reset folder (used by any reset, per Microsoft's
"Recovery components" page). These are two separate paths: E-3 and C-1 test the first, C-4 the second.

**D-5. Fleet's built-in wipe offers `doWipe` and `doWipeProtected` only.**
`server/fleet/windows_mdm.go` (`MDMWindowsWipeType`). The persist variants go out as custom commands. Payloads are in
Fleet's MDM command library (`docs/mdm-commands.yml`). A-3 confirms the wipe API rejects the others.

**D-6. Adding `org_settings.mdm` to `default.yml` changes nothing else.**
GitOps builds the `mdm` map whether or not the YAML has one, and fills the same defaults for missing keys either way
(`server/service/client.go`, "Ensure mdm config exists", about line 2452). So the new block only adds the IdP. The
dry run in S-2 confirms it.

**D-7. Omnissa (VMware) built the same pattern for Workspace ONE.**
github.com/helmlingp/apps_DeviceWipewProvisioning (read 2026-10-26, last push 2023-12-07, no license).
`DeviceWipewProvisioning.ps1`, deployed as a Workspace ONE app, copies the provisioning package to
`C:\Recovery\Customizations`, an `unattend.xml` to `C:\Recovery\AutoApply`, and optionally the agent MSI to
`C:\Recovery\OEM`. The admin then sends "Device Wipe with Provisioning Data", which is `doWipePersistProvisionedData`.
The README says it works for "brownfield" devices that were not set up with a package, and describes the device
coming back to the same setup flow as a factory-provisioned one. The script sets no ACLs on `C:\Recovery`. The Fleet
equivalent: a Fleet script (or policy automation) stages Fleet's package in `C:\Recovery\Customizations`, then Fleet
sends `doWipePersistProvisionedData`. Confirmed by C-4.

**D-8. Fleet's MDM command library payloads for Windows don't run as published.**
`docs/mdm-commands.yml` wraps each Windows command in `<syncml><syncbody>`. `fleetctl mdm run-command` rejects that with
"You can run only <Exec> command type." (`server/fleet/microsoft_mdm.go`, `ParseWindowsMDMCommand`). The bare
`<Exec>` element works (`payloads/README.md`). Docs fix to propose.


## Lab versus production

- VMs with Ethernet. Real laptops often have only Wi-Fi, so they reach Fleet only after the end user picks a network.
- arm64 VMs. Most customer laptops are x64. Run C-1 once on a physical x64 laptop before changing any guide.
- No TPM, so no BitLocker during the reset (X-8). Fleet-managed laptops usually have BitLocker on.
- One hosts file line in the VM (`idp.ppkg.test`) so it can reach the mock IdP. Real IdPs are public. A reset removes
  the line, so it is added again at the region screen.
- The package is opened from a USB drive with Shift+F10 at the region screen, close to but not the same as Windows
  setup picking it up from a drive.
- Each VM keeps its SMBIOS UUID and serial across resets, as hardware does. Fleet matches hosts on these.
- VMs run on Homebrew QEMU (`testing/_framework/vm/README.md`).
