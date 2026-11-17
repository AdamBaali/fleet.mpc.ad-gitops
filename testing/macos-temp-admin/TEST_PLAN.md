# Test plan: Temporary admin rights on macOS

Issue: none (customer question) · Owner: Adam · Environment: lab Fleet, Temp Admin Lab fleet · Started: 2026-11-17

## Scope
A customer gives non-engineers admin rights for 20 minutes from their old MDM. IT support scopes a policy to a static
group, the policy runs a script that promotes the user, and a LaunchDaemon demotes them after 20 minutes. This plan tests
the same flow in Fleet with `lib/macos/scripts/temp-admin.sh`, offered two ways:

- Saved script: IT support runs it from the host page. The Technician role can run saved scripts but can't edit them or
  run arbitrary scripts (`articles/role-based-access.md` at `fleet-v4.95.0`, lines 118 to 122).
- Self-service: the same script as a script-only package, visible only to hosts in the manual label
  "Temp admin approved". IT support adds or removes the host (Technicians can, line 53). The user runs it from Fleet Desktop.

Option 2 uses SAP Privileges, which the customer already runs for engineers, in the `Privileges Lab` fleet
(`fleets/privileges-lab.yml`). IT support adds the Mac to the manual label "Privileges approved". The label does two things:
the user sees Privileges (Fleet-maintained app `privileges/darwin`, 2.6.0) in self-service, and the Mac gets a profile with
`ExpirationInterval` = 20, `AllowPrivilegeRenewal` = false, `ReasonRequired` = true and `RevokePrivilegesAtLogin` = true.
Macs outside the label get `EnforcePrivileges` = `user`. That also covers a Mac that leaves the label with Privileges still
installed, because Fleet doesn't uninstall software that goes out of scope. Every Mac gets a base profile that approves the
Privileges background items and notifications. Keys are from SAP's Managing Privileges wiki and the ProfileManifests
`corp.sap.privileges` manifest. The payload format matches SAP's Privileges MDM Configurator
(`com.apple.ManagedClient.preferences`).

The two options run in separate fleets so they never act on one Mac.

## Environment
| Item | Value |
|---|---|
| Fleet | fleet.mpc.ad, 4.94.0, Premium. Option 1: `Temp Admin Lab` (`fleets/temp-admin-lab.yml`). Option 2: `Privileges Lab` (`fleets/privileges-lab.yml`) |
| Hosts | One lab Mac with a standard user signed in, and an admin account for checks |
| Other systems | none |
| Lab differences from production | GitOps mode is off in the lab. With GitOps mode on, the UI blocks label edits, so IT support adds hosts through the API (`POST /api/v1/fleet/hosts/:id/labels`). The lab doesn't run GitOps on a schedule. P-8 runs it by hand to stand in for the 6am run |

## Tests
| ID | Test | Steps | Expected | Pass when |
|---|---|---|---|---|
| T-1 | Host facts | Run `hosts/host-facts.sh` | Versions recorded | Output saved |
| T-2 | Promote from saved script | Standard user signed in. Run the saved script from the host page | Script exits 0, user is in admin | `dseditgroup -o checkmember -m <user> admin` says yes, log shows the expiry |
| T-3 | Demote after 20 minutes | Wait 21 minutes after T-2 | User is standard again, daemon and state removed | checkmember says no, `launchctl print system/com.fleetdm.temp-admin` fails, log line "standard user again" |
| T-4 | Demote survives a restart | Run T-2, restart the Mac before 20 minutes, sign in after expiry | User demoted within a minute of boot | Log line within 60 s of expiry or boot, whichever is later |
| T-5 | Permanent admin left alone (negative control) | Sign in as an admin that was never granted. Run the script | Nothing changes | Exit 0, log says "already an admin", no daemon loaded, user still admin after 21 minutes |
| T-6 | Repeat run restarts the clock | Run T-2, then run again at minute 10 | Expiry moves to minute 30 | Demotion at minute 30, not 20 |
| T-7 | Self-service from label | Add the host to "Temp admin approved". User opens Fleet Desktop and runs "Admin rights for 20 minutes". Remove the host from the label | Item shows only while the host is in the label, and promotes the user | Item visible then hidden, T-2 checks pass |
| T-8 | Technician workflow | Sign in as a Technician. Add the host to the label and run the saved script. Try to edit the script | Label change and run work, edit is blocked | UI shows each outcome |
| T-9 | Self-service rerun | After T-7 expires, run the item again from Fleet Desktop | It runs again without IT support resetting anything | Second promotion logged |

### Option 2: SAP Privileges

| ID | Test | Steps | Expected | Pass when |
|---|---|---|---|---|
| P-1 | Not approved | Move the Mac to Privileges Lab. Open Fleet Desktop as the standard user | Privileges isn't in self-service. Locked profile installed | Self-service list has no Privileges, `defaults read /Library/Managed\ Preferences/corp.sap.privileges` shows `EnforcePrivileges = user` |
| P-2 | IT support approves | Add the Mac to "Privileges approved". User installs Privileges from self-service | Privileges shows in self-service and installs. Fleet removes the locked profile and installs the 20-minute one | Install succeeds, the host's profile list shows the swap, managed preferences show `ExpirationInterval = 20` |
| P-3 | User takes 20 minutes | Open Privileges, enter a reason, request admin | User is an admin, the reason is logged | checkmember says yes, the reason appears in the unified log for `corp.sap.privileges` |
| P-4 | Expires at 20 minutes, no renewal | Wait 21 minutes | No renewal button. User is standard | checkmember says no at minute 21 |
| P-5 | IT support revokes mid-grant | Request admin, then remove the Mac from the label at minute 5 | Privileges leaves self-service but stays installed. Locked profile returns and demotes the user | Self-service list has no Privileges, checkmember says no within a few minutes of the profile landing, the app can't grant admin again |
| P-6 | Restart ends a grant | Request admin, restart, sign in | Admin removed at login | checkmember says no after login |
| P-7 | Profiles never overlap | During P-2 and P-5, list installed profiles | Only one of the locked and 20-minute profiles is installed at a time | `profiles list` never shows both |
| P-8 | Daily clear | Add the Mac to "Privileges approved" with `POST /api/v1/fleet/hosts/:id/labels`, then run GitOps (the label has `hosts: []`) | The label is empty after the run and the locked profile returns | `fleetctl get labels` and the host's profile list show the Mac out of the label and locked |

## Out of scope / not tested
- Option 1: demoting the user when the label is removed during an active grant. The grant still ends at its expiry. Option 2 covers this in P-5.
- macOS versions other than the lab Mac's.
- Privileges `RemoteLogging` to the customer's log server or webhook. We don't know their endpoint.
- A user removing the LaunchDaemon while they're an admin. Any admin can do this. Fleet can catch it with a policy
  (later work).
