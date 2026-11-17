# Test plan: Temporary admin rights on macOS

Issue: none (customer question) · Owner: Adam · Environment: lab Fleet, Temp Admin Lab fleet · Started: 2026-11-17

## Scope
A customer gives non-engineers admin rights for 20 minutes from their old MDM. IT support scopes a policy to a static
group, the policy runs a script that promotes the user, and a LaunchDaemon demotes them after 20 minutes. IT support
flushes the policy to allow another grant.

The Fleet version is one script, `lib/macos/scripts/temp-admin.sh`, offered two ways from the same file:
- Self-service: a script-only package, "Admin rights for 20 minutes". The user clicks Run in Fleet Desktop when they need
  admin. Fleet labels script packages Run, then Rerun (`TileActionStatus.tsx` at `fleet-v4.95.0`), so each click is one
  20-minute grant with nothing to reset.
- Saved script: IT support runs it from the host page for a user who can't. The Technician role can run saved scripts but
  can't edit them or run arbitrary scripts (`articles/role-based-access.md` at `fleet-v4.95.0`, lines 118 to 122). GitOps
  mode doesn't block running scripts: `RunScriptModal.tsx` and `ConfirmRunScriptModal.tsx` have no GitOps mode check,
  while label editing (`HostsFilterBlock.tsx`) and script deletion (`ScriptDetailsModal.tsx`) do.

There's no label or profile, so IT support has nothing to approve or clear. The trade-off: any user in the fleet can take
20 minutes whenever they like, and can rerun it. IT support sees every run in the activity log.

An earlier version of this lab tried label-gated self-service and SAP Privileges with label-switched profiles. Under
GitOps mode both needed the API to approve and a daily clear, so they were dropped.

## Environment
| Item | Value |
|---|---|
| Fleet | fleet.mpc.ad, 4.94.0, Premium. `Temp Admin Lab` (`fleets/temp-admin-lab.yml`) |
| Hosts | One lab Mac with a standard user signed in, and an admin account for checks |
| Other systems | none |
| Lab differences from production | GitOps mode is off in the lab. T-7 turns it on for the test and back off after |

## Tests
| ID | Test | Steps | Expected | Pass when |
|---|---|---|---|---|
| T-1 | Host facts | Run `hosts/host-facts.sh` | Versions recorded | Output saved |
| T-2 | Promote from saved script | Standard user signed in. Run the saved script from the host page | Script exits 0, user is in admin | `dseditgroup -o checkmember -m <user> admin` says yes, script output shows the expiry |
| T-3 | Demote after 20 minutes | Wait 21 minutes after T-2 | User is standard again, daemon and state removed | checkmember says no, `launchctl print system/com.fleetdm.temp-admin` fails, log line "standard user again" |
| T-4 | Demote survives a restart | Run T-2, restart the Mac before 20 minutes, sign in after expiry | User demoted within a minute of boot | Log line within 60 s of expiry or boot, whichever is later |
| T-5 | Permanent admin left alone (negative control) | Sign in as an admin that was never granted. Run the script | Nothing changes | Exit 0, output says "already an admin", no daemon loaded, user still admin after 21 minutes |
| T-6 | Run again restarts the clock | Run T-2, then run again at minute 10 | Expiry moves to minute 30 | Demotion at minute 30, not 20 |
| T-7 | Technician with GitOps mode on | Turn GitOps mode on. Sign in as a Technician. Run the saved script on the host. Try to edit or delete it | Run works, edit and delete are blocked | UI shows each outcome, the activity log names the Technician |
| T-8 | Nobody signed in | Run the script at the login window | Nothing changes | Exit 1, output says "No user is signed in" |
| T-9 | Self-service run | Standard user opens Fleet Desktop > Self-service and clicks Run on "Admin rights for 20 minutes" | Script runs, user is in admin, the tile then shows Rerun | checkmember says yes, the activity log shows the run, the tile says Rerun |
| T-10 | Self-service rerun | After T-9 expires, click Rerun | Second 20-minute grant | Second promotion and demotion logged |

## Out of scope / not tested
- Ending a grant early. It runs to its expiry. A second saved script could end it if IT support asks for that.
- macOS versions other than the lab Mac's.
- A user removing the LaunchDaemon while they're an admin. Any admin can do this. A Fleet policy on the `users`, `groups`
  and `user_groups` tables could catch it (later work).
