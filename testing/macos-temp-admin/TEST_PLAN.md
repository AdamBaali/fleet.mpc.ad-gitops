# Test plan: Temporary admin rights on macOS

Issue: none (customer question) · Owner: Adam · Environment: lab Fleet, Temp Admin Lab fleet · Started: 2026-11-17

## Scope
A customer gives non-engineers admin rights for 20 minutes from their old MDM. When someone needs admin, IT support adds
their Mac to a static group. A policy scoped to that group runs once per computer: its script promotes the user, and a
LaunchDaemon demotes them after 20 minutes. IT support flushes the policy run to allow another grant.

The Fleet version, in `fleets/temp-admin-lab.yml`:
- IT support approves a Mac by running the saved script `lib/macos/scripts/temp-admin-approve.sh` from its page. It writes
  `/Library/Application Support/Fleet/temp-admin-approved`. That's adding the Mac to the static group.
- A dynamic label, "Temp admin approved", matches Macs where that file exists (`file.path`, a macOS column in Fleet's schema
  at `fleet-v4.95.0`). The self-service item "Admin rights for 20 minutes" (`lib/macos/scripts/temp-admin.sh`, a
  script-only package) only shows for that label.
- The user runs the item from Fleet Desktop. The script refuses without the approval file. After a successful grant it
  deletes the file, so the approval is used up and the item disappears. There's nothing to remove or flush: the next
  approval is the next grant.
- Labels refresh about hourly by default (`docs/Configuration/fleet-server-configuration.md`,
  `osquery_label_update_interval`). So both scripts ask Fleet to refetch the host after changing the file, with the Fleet
  Desktop token (`/opt/orbit/identifier`) and the Fleet URL (`ORBIT_FLEET_URL` in the orbit LaunchDaemon), using
  `POST /api/latest/fleet/device/{token}/refetch`. A refetch makes Fleet send the label queries on the next check-in
  regardless of the interval (`server/service/osquery.go` line 1525 at `fleet-v4.95.0`). The grant script's own check
  still enforces the limit if the refetch fails. The refetch call alone returned HTTP 200 from a lab Mac on 2026-11-17.

Why this fits IT support:
- The Technician role can run saved scripts but can't edit them or run arbitrary scripts (`articles/role-based-access.md`
  at `fleet-v4.95.0`, lines 118 to 122).
- GitOps mode doesn't block running scripts: `RunScriptModal.tsx` and `ConfirmRunScriptModal.tsx` have no GitOps mode check,
  while label editing (`HostsFilterBlock.tsx`) and script deletion (`ScriptDetailsModal.tsx`) do. A manual label would need
  the API to change under GitOps mode. An approval file set by a saved script doesn't.

Checked without a Mac (2026-11-17):
- `scripts/harness.sh` runs both scripts against stubs for `dseditgroup`, `launchctl`, `curl` and the console user, with
  every path in a scratch folder. 17 of 17 checks pass: refusal without approval, approval and a repeat approval, grant
  using up the approval, refusal after that, demotion at expiry, a new approval allowing one more grant, a failed grant
  keeping its approval, a permanent admin left alone, and nobody signed in. With the approval check removed, 7 checks fail.
  With the line that uses up the approval removed, 4 fail.
- The same label query shape, run in osqueryi 5.18.1 against a stand-in file, matches when the file exists and not when
  it's missing.

Why not SAP Privileges for this: its 2.6.0 release (the latest, and Fleet's maintained version) has no setting for one grant
per approval. `AdminBudget` limits admin minutes per day, but SAP's wiki marks it Privileges 2.7.0+, which isn't released.
`PostChangeExecutablePath` runs as the user's `PrivilegesAgent`, not root, so it can't end an approval on its own.

An earlier version of this lab tried a manual label with a daily clear, and SAP Privileges with label-switched profiles.
Both needed the API to approve under GitOps mode, so they were dropped.

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
| T-2 | Not approved | Standard user opens Fleet Desktop > Self-service | No "Admin rights for 20 minutes" item | Item absent, Mac not in "Temp admin approved" |
| T-3 | IT support approves | Run `temp-admin-approve.sh` from the host page | Approval file written, refetch requested, item shows within minutes | Output says "Approved" and "Asked Fleet to refetch", Mac joins the label well before the hourly refresh, item shows |
| T-4 | User takes the grant | User clicks Run on the item | User is an admin, approval used up, item disappears within minutes | `dseditgroup -o checkmember -m <user> admin` says yes, approval file gone, Mac leaves the label, item gone |
| T-5 | Demote after 20 minutes | Wait 21 minutes after T-4 | User is standard again, daemon and state removed | checkmember says no, `launchctl print system/com.fleetdm.temp-admin` fails, log line "standard user again" |
| T-6 | Demote survives a restart | Approve, grant, restart the Mac before 20 minutes, sign in after expiry | User demoted within a minute of boot | Log line within 60 s of expiry or boot, whichever is later |
| T-7 | Technician with GitOps mode on | Turn GitOps mode on. Sign in as a Technician. Run `temp-admin-approve.sh` on the host. Try to edit or delete it | Run works, edit and delete are blocked | UI shows each outcome, the activity log names the Technician |
| T-8 | Permanent admin left alone (negative control) | Approve, sign in as an admin that was never granted, run the item | Nothing changes | Exit 0, output says "already an admin", no daemon loaded, approval kept |
| T-9 | Nobody signed in (negative control) | Approve, run `temp-admin.sh` at the login window | Nothing changes | Exit 1, output says "No user is signed in", approval kept |
| T-10 | A new approval allows one more grant | After T-5, approve again and run the item | Second grant, item disappears again | Second promotion and demotion logged |

## Out of scope / not tested
- Approvals don't expire. An unused approval stays until the user runs the item, like a Mac left in a static group.
- Ending a grant early. It runs to its expiry.
- A user who is an admin during their 20 minutes writing their own approval file, or removing the LaunchDaemon. Any admin
  can do this, the same as with the old MDM's script. A Fleet policy on the `users`, `groups` and `user_groups` tables
  could catch leftover admins (later work).
- macOS versions other than the lab Mac's.
