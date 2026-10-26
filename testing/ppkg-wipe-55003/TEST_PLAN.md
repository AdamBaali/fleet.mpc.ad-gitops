# Test plan: reset a Windows host with a provisioning package (fleetdm/fleet#55003)

Issue: https://github.com/fleetdm/fleet/issues/55003 (thread from comment 6330622182) · Owner: Adam · Started: 2026-10-26 · Status: planned, nothing run

Question: after an MDM wipe, does a Windows host that was set up with Fleet's provisioning package (`.ppkg`) come back
to the first setup screen with fleetd installed and enroll in Fleet again on its own? And what does the end user see
when the fleet requires end user authentication, with and without `--bypass-end-user-auth`?

The design review needs three answers:
1. Which wipe keeps fleetd: `doWipePersistProvisionedData`, `doWipeCloudPersistProvisionedData`, or neither.
2. Does the host check in during setup, or only after the end user signs in (the quote in the thread says the second).
3. Can Fleet put the package on a host that was enrolled another way, so admins and end users do nothing extra.


## Scope

Covers: Windows 11 Pro in a UTM VM, Fleet's ppkg guide as written, two fleetd builds (bypass on and off), four wipe
types sent from Fleet, and a fleet with end user authentication on, backed by a lab IdP.

Doesn't cover: Autopilot and Entra join (Fleet installs fleetd itself there), Windows 10, physical hardware, BitLocker
on during the reset, and `doAutomaticRedeployment` (needs Autopilot). See [NOTES.md](NOTES.md) for lab versus production.


## Environment

| Item | Value |
|---|---|
| Fleet | `https://fleet.mpc.ad`, version recorded in S-0, Premium, Windows MDM on (`default.yml`) |
| Fleet server setting | `mdm.allow_orbit_end_user_auth_bypass`: default `true`. Record the live value in S-0. Don't change it unless a test says so |
| Fleet code checked | `fleet-v4.93.2` (the latest tag on 2026-10-26). Re-check at the lab's version if it differs |
| Test fleet | New fleet **Windows Reset Lab**, `fleets/windows-reset-lab.yml` (draft below). End user authentication on |
| IdP | Mock SAML IdP (SimpleSAMLphp, Fleet's dev image) in Docker on the Mac, own signing key, two fake users. [IDP_SETUP.md](IDP_SETUP.md) |
| Test VM | UTM on the Mac, Windows 11 Pro 26H2 arm64, UEFI, TPM 2.0, 80 GB disk, stopped at the region screen (S-3) |
| Builder VM | A second Windows VM with Windows Configuration Designer (WCD), for building the packages (S-4) |
| Lab differences | VM not laptop, arm64 not x64, SMBIOS UUID and serial set by UTM, no Wi-Fi page in setup. See NOTES.md |


## Setup (S)

| ID | Step | Pass when |
|---|---|---|
| S-0 | Record the lab: Fleet version (`fleetctl --version`, `fleetctl get config --include-server-config`), the live `allow_orbit_end_user_auth_bypass`, and that no other fleet has `enable_end_user_authentication` on | Values saved to `test-evidence/setup/S-0-*/` |
| S-1 | IdP: `idp/setup.sh`, then `docker compose up -d` ([IDP_SETUP.md](IDP_SETUP.md)) | A test login returns a signed response with Name ID = the user's email, for Fleet's callback. **Done 2026-10-26** |
| S-2 | Fleet: add `mdm.end_user_authentication` to `default.yml`, add `fleets/windows-reset-lab.yml`, add both secrets to `workflow.yml`. Branch, PR, merge | GitOps run green. **Settings > Integrations > SSO > End users** shows the IdP. Fleet shows "Windows Reset Lab" with end user authentication on. Other fleets unchanged |
| S-3 | Test VM: install Windows 11 Pro 26H2 arm64 with an answer file that only covers the `windowsPE` pass, so first boot stops at the region screen. Shut down there. APFS-clone the UTM bundle as `ppkg-golden-oobe` (`cp -c`) | Each test starts from a fresh clone and boots to the region screen |
| S-3b | From a clone at the region screen: Shift+F10, `reagentc /info`, `winver`, `wmic csproduct get uuid,identifyingnumber` | WinRE **Enabled**. Build recorded. UUID and serial recorded (Fleet matches hosts on these) |
| S-4 | Builder VM: install WCD from the Microsoft Store. Reuse an existing Windows VM if one is free. It must never enroll in Fleet | WCD opens **Advanced provisioning** |
| S-5 | Build two arm64 MSIs for "Windows Reset Lab", secret read from `.env`, never printed (adapt `../bitlocker-pin-42318/tools/build-windows-msi.sh`):<br>**MSI-B** (bypass): `--fleet-desktop --enable-scripts --disable-setup-experience --bypass-end-user-auth`<br>**MSI-N** (no bypass): same without `--bypass-end-user-auth` | Two MSIs. `msiexec /a` extract, or WiX dark, shows `ORBIT_BYPASS_END_USER_AUTH=true` only in MSI-B |
| S-6 | In WCD, build **PKG-B** and **PKG-N** exactly as the guide says (ProvisioningCommands, Owner IT Admin, encrypted). One MSI per project folder | Two `.ppkg` files. Passwords in `private/`, never in evidence |
| S-7 | Delivery: one small FAT32 disk image per package, the `.ppkg` at its root, attached to the VM as a UTM removable USB drive | At the region screen Windows offers to install the package. If it doesn't, press Windows five times. Fallback (record it if used): Shift+F10, `Install-ProvisioningPackage` from the drive |

Draft fleet file for S-2 (not committed yet):

```yaml
# Lab fleet for testing reset with a provisioning package (fleetdm/fleet#55003).
# End user authentication is on so we see when fleetd waits for the IdP and when it doesn't.
name: "Windows Reset Lab"
policies:
reports:
agent_options:
controls:
  setup_experience:
    enable_end_user_authentication: true
software:
settings:
  secrets:
    - secret: "$FLEET_WINDOWS_RESET_LAB_ENROLL_SECRET"
```

Draft addition to `default.yml` `org_settings` for S-2:

```yaml
  mdm:
    end_user_authentication:
      idp_name: Lab IdP
      entity_id: fleet-mpc-ad-end-users
      metadata: |
        <contents of idp/metadata.xml>
```

Check before merging: `fleetctl gitops --dry-run` with the new keys, and that the `mdm:` block doesn't reset other global
MDM settings set outside GitOps.


## First setup (E): apply the package at the region screen

Run each on a fresh clone. For each: screenshot the UTM window at every prompt, Shift+F10 `sc query "Fleet osquery"`,
note the time the host appears in Fleet, and collect `C:\Windows\Temp\orbit*.log`, `C:\Program Files\Orbit\` logs, and
the Render log lines with the host's UUID (`blocking enrollment` or `allowing enrollment without end-user authentication`).

| ID | Package | Steps | Expected | Pass when |
|---|---|---|---|---|
| E-1 | PKG-B | Apply at the region screen. Wait 3 minutes. Check Fleet. Finish setup with local user `lab1` | Enrolls at the setup screen with no prompt. MDM "Off" until `lab1` signs in, then "On". No IdP user on the host | Host in "Windows Reset Lab" before any user exists. No browser or "Get an app" prompt. MDM On after sign-in |
| E-2 | PKG-N | Same | Server blocks enrollment (no prior record). fleetd tries to open the Fleet sign-in page during setup and Windows shows "Get an app to open this 'https' link" | Not in Fleet during setup. Prompt seen (or not, record which). Render log shows `blocking enrollment` |
| E-2b | PKG-N | Continue E-2: finish setup as `lab1`, wait at the desktop | fleetd opens the browser to Fleet's sign-in. IdP sign-in as `eua-user-1`. Host enrolls and shows the IdP user | Host enrolled with `eua-user-1` under **Device user**. Time from desktop to enrollment recorded |
| E-3 | both | After E-1 and E-2b, record where Windows kept the package: `Get-ProvisioningPackage -AllInstalledPackages`, `dir C:\ProgramData\Microsoft\Provisioning -s`, `dir C:\Recovery -s -Force`, ACLs on those folders | Microsoft says persisted packages live in `ProgramData\Microsoft\Provisioning`. `C:\Recovery\Customizations` likely empty | Locations and ACLs recorded. Note if a standard user can read the package (it holds the enroll secret) |
| E-4 | both | Clone each VM at this point (enrolled, MDM On, user signed in) as `after-E1` and `after-E2b` | Starting points for the W tests | Two clones saved |


## Wipe (W): send the wipe from Fleet, then watch the host come back

Send custom commands with `fleetctl mdm run-command --hosts=<hostname> --payload=<file>`. Payloads in `payloads/`,
copied from Fleet's MDM command library (`docs/mdm-commands.yml` at the tag). Built-in wipes go through the UI or
`POST /api/v1/fleet/hosts/:id/wipe` with `windows.wipe_type`.

For each run record:
1. Command status in Fleet and the time Windows started the reset.
2. Does the VM reach the region screen? Any prompt for the package password or for trust?
3. At the region screen: Shift+F10, `sc query "Fleet osquery"`, the package locations from E-3.
4. Does the host check in during setup (Fleet **Last seen**, Render log), or only after sign-in?
5. Same host record or a new one. Host ID, wipe status, MDM status, IdP user, activity feed.
6. After sign-in as `lab2`: MDM On again? Profiles and software from the fleet re-sent?
7. Total time from command to desktop.

Tier 1 (answers the design review):

| ID | Start from | Wipe | Fleet record | Expected | Pass when |
|---|---|---|---|---|---|
| W-1 | after-E1 | `doWipePersistProvisionedData` | Keep | Reset to region screen. Package re-applied, fleetd running at setup, same host checks in before sign-in | fleetd running at the region screen and host checks in before `lab2` exists |
| W-2 | after-E2b | `doWipePersistProvisionedData` | Keep | fleetd back. Server treats it as a re-enroll (`HostPreviouslyOrbitEnrolled`) and lets it in **without** the IdP | Host checks in with no browser prompt. If it waits for the IdP, the quote in the thread holds. Record which |
| W-3 | after-E2b | `doWipePersistProvisionedData` | Delete the host in Fleet after the command is acknowledged, before the VM finishes resetting | Server sees a new host. Blocks enrollment. Prompt at setup as in E-2, IdP at the desktop as in E-2b | Behaves like E-2 and E-2b. Sign in as `eua-user-2`. Fleet shows `eua-user-2` |
| W-4 | after-E1 | Fleet's **Wipe** button (`doWipeProtected`) | Keep | Clean reset. Package and fleetd gone. Host stays "Wiped" in Fleet | No fleetd at the region screen. Negative control: if fleetd survives, the other results need rethinking |

Tier 2 (fills the matrix):

| ID | Start from | Wipe | Fleet record | Expected | Pass when |
|---|---|---|---|---|---|
| W-5 | after-E1 | `doWipeCloudPersistProvisionedData` | Keep | Like W-1, after downloading a fresh arm64 image. Record download time and free space needed | Like W-1 |
| W-6 | after-E1 | API wipe with `wipe_type: doWipe` | Keep | Package and fleetd gone | No fleetd at the region screen |
| W-7 | after-E1, then copy PKG-B to `C:\Recovery\Customizations` with the ACLs from Microsoft's guide | API `doWipe` | Keep | Push-button reset restores packages in that folder, so fleetd comes back | fleetd running at the region screen |
| W-8 | after-E1, staged as in W-7 | Fleet's **Wipe** button (`doWipeProtected`) | Keep | The thread says this removes the recovery folder, so fleetd doesn't come back | Record. Confirms or corrects the claim in the thread |
| W-9 | W-1's host, after it reaches the desktop | `doWipePersistProvisionedData` again | Keep | Second reset works the same. The package survives more than one reset | Same as W-1 |

Fleet-side state after W-4 and W-6: Fleet marks the host "Wiped" and refuses another wipe ("Host is already wiped").
Record whether re-enrollment clears that state, since a repurposed host needs it cleared.


## No package at setup (P): can Fleet add it later?

The thread asks whether Fleet can set this up for hosts enrolled another way. Start from a fresh clone, finish setup
with a local user, and install MSI-B directly (no package).

| ID | Steps | Expected | Pass when |
|---|---|---|---|
| P-1 | Fleet script copies PKG-B (unencrypted build, see NOTES) into `C:\Recovery\Customizations` with Microsoft's ACLs. Then API `doWipe` | Same as W-7 | fleetd running at the region screen |
| P-2 | Fleet script runs `Install-ProvisioningPackage -PackagePath <PKG-B> -QuietInstall -ForceInstall` on the running host. Then `doWipePersistProvisionedData` | A package installed at run time is also persisted, so fleetd comes back | fleetd running at the region screen. If not, only packages applied during setup persist |
| P-3 | Size and source: how the script gets the `.ppkg` (Fleet software package, or a download URL) | Recorded for the design review | Working method written down |


## Order and time

1. S-0 to S-2 (IdP and Fleet, about 1 hour).
2. S-3 to S-7 (VMs and packages, about 3 hours, mostly installs).
3. E-1 to E-4 (about 1.5 hours).
4. W-1 to W-4, then stop and write up. These answer the design review.
5. W-5 to W-9 and P-1 to P-3 if time allows.

Each reset in a VM takes 30 to 60 minutes. Run two clones at once if the Mac has the RAM.


## Done when

W-1 to W-4 have results, `RESULTS.md` is written, and `drafts/ISSUE_UPDATE.md` answers the three questions for Adam to post.


## Out of scope / not tested

- Autopilot, Entra join, and `doAutomaticRedeployment`: need Microsoft licenses and an Entra tenant.
- Windows 10 and x64 hardware: run W-1 on one physical x64 laptop before any guide change ships.
- BitLocker on during the reset: likely matters for real laptops. Follow-up test.
- Wi-Fi only hosts: the VM uses Ethernet. Real hosts reach Fleet only after the end user picks a network.
