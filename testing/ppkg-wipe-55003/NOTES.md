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


**D-7. Omnissa (VMware) built the same pattern for Workspace ONE.**
github.com/helmlingp/apps_DeviceWipewProvisioning (Phil Helmling; read 2026-10-26, last push 2023-12-07, no license).
`DeviceWipewProvisioning.ps1`, deployed as a Workspace ONE app, copies the provisioning package to
`C:\Recovery\Customizations`, an `unattend.xml` to `C:\Recovery\AutoApply`, and optionally the agent MSI to
`C:\Recovery\OEM`. The admin then sends "Device Wipe with Provisioning Data", which is `doWipePersistProvisionedData`.
The README says it works for "brownfield" devices that were not set up with a package, and describes the device
coming back to the same setup flow as a factory-provisioned one. The script sets no ACLs on `C:\Recovery`. The Fleet
equivalent: a Fleet script (or policy automation) stages Fleet's package in `C:\Recovery\Customizations`, then Fleet
sends `doWipePersistProvisionedData`. Test W-6.

**D-8. Fleet's MDM command library payloads for Windows don't run as published.**
`docs/mdm-commands.yml` wraps each Windows command in `<syncml><syncbody>`. `fleetctl mdm run-command` rejects that with
"You can run only <Exec> command type." (`server/fleet/microsoft_mdm.go`, `ParseWindowsMDMCommand`). The bare
`<Exec>` element works (`payloads/README.md`). Docs fix to propose.


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


## Lab fix: Homebrew QEMU instead of UTM (2026-10-27)

UTM 4.7.5 hung at "Start boot option" on the first boot after every reset or generalize, warm or cold (L-2). The same
disk boots on Homebrew `qemu-system-aarch64` 11.1.2 with Homebrew's edk2 and an empty NVRAM: sysprep generalize
came back to the region screen in about a minute (L-2C). So the hang is in UTM's QEMU/edk2, not Windows.

What the search turned up, for the record:
- utmapp/UTM#7648: hang at "Start boot option" after a guest restart. Open, still present in UTM 5.0.x betas. Another
  QEMU-based app shows it too, which points at QEMU or edk2.
- utmapp/UTM#7884: a Windows 11 arm64 VM hangs after a guest tools driver change; Secure Boot left half-migrated to the
  2023 CA. Not our cause: our image had no Secure Boot keys enrolled.
- Broadcom KB 390487 and 400708: sysprep `/generalize` on 24H2 and later can leave bad BCD entries ("Failed to export
  alterations to firmware") or a black screen on first sign-in. Not hit on QEMU 11.
- The EFI variable store was not full (242 KB of 256 KB free), so that was not the cause either.

The lab now runs VMs with `tools/qemu-boot.sh` (headless, an overlay on a base disk, a fixed SMBIOS UUID and serial per
VM), `tools/qmp.sh` (screens, keys, clicks), `tools/qga.sh` (PowerShell through the guest agent), and
`tools/qemu-watch.sh` (screens kept as evidence while a VM resets). Free, scriptable, and nothing on screen to click.

Limits: upstream QEMU's arm TPM device fails under HVF, so VMs run without a TPM (`TPM=1` tries it). Letters sent with
QMP `send-key` don't reach a command prompt opened over the setup screen; use the guest agent. The guest agent comes
from UTM guest tools, which a reset removes.

The tools and these lessons moved to `testing/_framework/vm/` for other projects; `tools/q*` link there.

Lessons from running C-1 to C-4 on QEMU:
- Display: ramfb only. With virtio-gpu attached, the first boot after sysprep generalize fails with 0xc0000001 and a
  reset sat idle with no picture, and power cycling it mid-reset left Windows unbootable (C-2). ramfb can show stale or
  black screens on the desktop under HVF; a restart with `GPU=virtio` fixes the picture when no reset follows (C-3).
- USB: QEMU's removable USB drive makes setup apply the package by itself and then show Provisioning failure
  0x800700b7 though fleetd installed (C-1, C-2). A fixed USB disk present during sysprep's reboot gave 0xc0000001.
  What worked: boot without it and hot-plug it as removable at the region screen (`tools/qmp.sh <vm> usb <img> true`),
  then open the package from Shift+F10 (C-2r).
- Run QEMU as a long-lived background task (`FG=1`). QEMU started inside a short tool call was killed with it.
- Put guest PowerShell in files (`payloads/local/`) and pass them with `"$(cat file)"`; nested quoting loses
  backslashes. Guest paths with forward slashes avoid the problem too.
- Typed `\` comes out as `#` in the golden image's layout. Use forward slashes (`cd /d C:/Windows/...`).
