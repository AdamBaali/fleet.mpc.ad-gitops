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

It doesn't cover SAP Privileges for engineers, which the customer keeps.

## Environment
| Item | Value |
|---|---|
| Fleet | fleet.mpc.ad, 4.94.0, Premium. Fleet `Temp Admin Lab` (`fleets/temp-admin-lab.yml`) |
| Hosts | One lab Mac with a standard user signed in, and an admin account for checks |
| Other systems | none |
| Lab differences from production | GitOps mode is off in the lab. With GitOps mode on, the UI blocks label edits, so T-8 checks whether a Technician can still add a host to the manual label |

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

## Out of scope / not tested
- Demoting the user when the label is removed during an active grant. The grant still ends at its expiry.
- macOS versions other than the lab Mac's.
- A user removing the LaunchDaemon while they're an admin. Any admin can do this. Fleet can catch it with a policy
  (later work).
