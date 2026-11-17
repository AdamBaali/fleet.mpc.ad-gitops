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

Each Mac gets one grant per 24 hours, with nothing for IT support to remember:
- Each grant writes `/Library/Application Support/Fleet/temp-admin-last-run`.
- The script refuses while that marker is newer than 24 hours.
- A dynamic label, "Temp admin used in last 24 hours", matches the same marker (`file.mtime` against `time.unix_time`,
  both macOS columns in Fleet's schema at `fleet-v4.95.0`). The self-service item excludes that label, so it disappears
  after a grant and comes back after the cooldown. Labels refresh about hourly by default
  (`docs/Configuration/fleet-server-configuration.md`, `osquery_label_update_interval`). So after writing the marker, the
  script asks Fleet to refetch the host with the Fleet Desktop token (`/opt/orbit/identifier`) and the Fleet URL
  (`ORBIT_FLEET_URL` in the orbit LaunchDaemon), using `POST /api/latest/fleet/device/{token}/refetch`. A refetch makes Fleet
  send the label queries on the next check-in regardless of the interval (`server/service/osquery.go` line 1525 at
  `fleet-v4.95.0`). The reset script does the same after deleting the marker. The script's own check still enforces the
  limit if the refetch fails. The refetch call alone returned HTTP 200 from a lab Mac on 2026-11-17.
- IT support runs the saved script `temp-admin-reset.sh` to clear the marker when a user needs a second grant early. That's
  the Fleet version of the flush.

The label query was checked locally with osqueryi 5.18.1 against a stand-in file: fresh and 23-hour-old markers match, a
2-day-old or missing marker doesn't.

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
| T-6 | Cooldown refuses a second grant | After T-2, run the script again | Refused, nothing changes | Exit 1, output gives the next available time, expiry unchanged |
| T-7 | Technician with GitOps mode on | Turn GitOps mode on. Sign in as a Technician. Run the saved script on the host. Try to edit or delete it | Run works, edit and delete are blocked | UI shows each outcome, the activity log names the Technician |
| T-8 | Nobody signed in | Run the script at the login window | Nothing changes | Exit 1, output says "No user is signed in" |
| T-9 | Self-service run | Standard user opens Fleet Desktop > Self-service and clicks Run on "Admin rights for 20 minutes" | Script runs, user is in admin, the tile then shows Rerun | checkmember says yes, the activity log shows the run, the tile says Rerun |
| T-10 | Item hides right after a grant | After T-9, read the script output and watch the host's labels | Output says "Asked Fleet to refetch this host". Within a few minutes the Mac joins "Temp admin used in last 24 hours" and the item leaves self-service | Label membership changes well before the hourly refresh, Fleet Desktop no longer shows the item |
| T-11 | IT support clears the cooldown | Run `temp-admin-reset.sh` from the host page, then run `temp-admin.sh` from self-service | Marker removed, refetch requested, the item comes back within minutes, second grant works | Reset output says "Cooldown cleared" and "Asked Fleet to refetch", the Mac leaves the label, second promotion logged |
| T-12 | Cooldown ends on its own | Set the marker's mtime to 25 hours ago with `touch -t`, wait for the label refresh | Item comes back and a run works | Mac leaves the label, self-service shows the item, run promotes the user |

## Out of scope / not tested
- Ending a grant early. It runs to its expiry.
- A user deleting the marker while they're an admin to skip the cooldown. Any admin can do this, the same as removing the LaunchDaemon.
- macOS versions other than the lab Mac's.
- A user removing the LaunchDaemon while they're an admin. Any admin can do this. A Fleet policy on the `users`, `groups`
  and `user_groups` tables could catch it (later work).
