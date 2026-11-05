# Results: require a PIN when company-owned Android hosts enroll (fleetdm/fleet#57607)

Plan: [TEST-PLAN.md](TEST-PLAN.md). Evidence per run: `test-evidence/<group>/<ID>-<slug>/` (build `EVIDENCE.md` with
`testing/_framework/bin/build-evidence-index.py`). Times are UTC. "T+" is minutes and seconds after the QR scan (T0).

Fleet version: 4.94.0 · Enrollment: QR (zero-touch in Z) · Code references: `fleet-v4.94.0`

## Summary

| Option | Runs | Passed | Result | One line |
|---|---|---|---|---|
| 2: profile at enrollment (`android-pin-test-block0`) | 4 | 1 PASS, 3 PARTIAL | PIN enforced in all 4 | Prompt in setup only when the policy reaches the phone during Device Policy's registering step (O2-1). Otherwise apps are blocked at home until a PIN is set (O2-2 to O2-4). A `shortSupportMessage` profile puts the unblock steps in the block dialog (O2-3, O2-4). No block during setup in 4 runs |
| Zero-touch confirmation | | | | |

## Setup

| ID | Date | Result | Notes |
|---|---|---|---|
| S-1 | 2026-11-05 | PASS | Fleet version: 4.94.0. Fleets 11-14 created; label fleet scopes pin-block-0 to `android-pin-ready` |
| S-2 | 2026-11-05 | PASS | Android MDM on. Labels exception: off |
| S-3 | 2026-11-05 | PASS | API works. Token is an admin fleetctl session token, not an API-only user |
| S-4 | | | |
| S-5 | | | |

## Runs: device and setup wizard

| ID | Date | Device model | Android version | Security patch | New or re-enrolled host | Pace | T0 (UTC) | Host in Fleet (T+) | Profile Pending (T+) | Wizard screen when policy arrived | PIN prompt in setup (screen) | "Blocked by your work policy" (screen) | Way past the block | Home screen (T+) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| O2-1 | 2026-11-05 | Samsung SM-A276B | 16 | 2026-05-05 | New | Normal | 09:37:24 to 09:37:48 | 5:05 to 5:29 (09:42:53) | 5:17 to 5:41 (09:43:05, failed USER_ACTION; pending 5 s before) | "Registering device..." (reconciler 09:42:57) | Yes, "Set a new screen lock" at 09:43:05 | No | n/a | 6:09 to 6:33 (09:43:57) |
| O2-2 | 2026-11-05 | Samsung SM-A276B | 16 | 2026-05-05 | New | Normal | about 10:37 (Wi-Fi 10:37:52) | 10:39:43 | 10:40:00 pending, 10:40:05 failed USER_ACTION | "Google services" (reconciler 10:39:59, 16 s after enrollment; registering ended 10:39:52) | No | No block screen in setup; apps blocked at the home screen | Device Policy notification "Unblock your apps" | 10:42:00 |
| O2-3 | 2026-11-05 | Samsung SM-A276B | 16 | 2026-05-05 | New | Fast (one 45 s pause on Google services) | about 11:14 (attempt 2; attempt 1 ended in "Can't set up device" before enrollment) | 11:16:00 | 11:16:16 pending, 11:16:39 failed USER_ACTION | "Google services" (applied 11:16:21; registering ended 11:16:14) | No | No block screen in setup; apps blocked at home | Custom block dialog text, then the notification | 11:17:44 |
| O2-4 | 2026-11-05 | Samsung SM-A276B | 16 | 2026-05-05 | New | Fast | about 11:26 | 11:28:00 | 11:28:19 pending, 11:28:41 failed USER_ACTION | After registering (applied 11:28:21) | No | No block screen in setup; apps blocked at home | Reworded block dialog text, then the notification | about 11:29 |
| O2-4 | | | | | | Slow | | | | | | | | |
| O2-5 | | | | | | Fast | | | | | | | | |
| Z-1 | | | | | | Normal | | | | | | | | |

## Runs: enforcement after setup

| ID | Fleet at enrollment | Move or label applied (T+) | Apps blocked (T+) | Apps blocked (which) | PIN prompt or notice after setup (T+) | PIN set (T+) | Profile status after PIN (T+) | Minutes usable without a PIN | Result | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| O2-1 | `android-pin-test-block0` | n/a | Not tested: PIN set before the home screen | n/a | 09:43:05, in setup | 09:43:37 | Verified 09:43:43 | 0 | PASS | [O2-1](test-evidence/O2/O2-1-option-2-normal-pace/result.md) |
| O2-2 | `android-pin-test-block0` | n/a | 10:42:00 (at the home screen) | All but Phone and Play Store: "Action not allowed... Contact your organisation's IT administrator" | Notification only, no screen | 10:45:48 | Verified 10:45:53 | 0 (blocked until the PIN) | PARTIAL | [O2-2](test-evidence/O2/O2-2-option-2-normal-pace/result.md) |
| O2-3 | `android-pin-test-block0` + unblock message | n/a | 11:17:44 (at the home screen) | All but Phone and Play Store: "Action not allowed" with the custom unblock text | Notification only, no screen | 11:18:12 | Verified 11:18:13 | 0 (blocked until the PIN) | PARTIAL | [O2-3](test-evidence/O2/O2-3-option-2-fast-pace/result.md) |
| O2-4 | `android-pin-test-block0` + reworded message | n/a | about 11:29 (at the home screen) | All but Phone and Play Store: "Action not allowed" with the reworded text | Notification only, no screen | 11:30:09 | Verified by 11:30:50 | 0 (blocked until the PIN) | PARTIAL | [O2-4](test-evidence/O2/O2-4-option-2-fast-pace/result.md) |
| O2-4 | `android-pin-test-block0` | n/a | | | | | | | | |
| O2-5 | `android-pin-test-block0` | n/a | | | | | | | | |
| Z-1 | zero-touch: | | | | | | | | | |

Add a row to both tables for each extra run (O2-6, Z-2, and so on).

## Findings

### F-4: `shortSupportMessage` replaces the text of the blocked-app dialog

With `pin-unblock-message.json` in the fleet (O2-3), tapping a blocked app on the Samsung showed Samsung's title
"Action not allowed" with the profile's text in place of "You do not have permission to perform this action. Contact
your organisation's IT administrator for more information." So the end user sees how to unblock without guessing.
Tested on one Samsung (One UI, Android 16) only. Other makes may lay out the dialog differently, so the message
shouldn't name Samsung-only steps.

### F-5: "Can't set up device" before enrollment (O2-3 attempt 1)

After a wipe through Fleet (`fleetctl mdm wipe`), the first QR attempt ended at "Can't set up device. If you have
any questions, contact your IT admin" after "Getting ready for work setup...". Google sent Fleet no enrollment, so no
Fleet policy was involved. Reset from that screen and a new QR worked. Cause unknown; one occurrence.

### F-3: option 2 depends on where enrollment falls in Fleet's 30-second profile job

Same fleet, same phone, same pace, two outcomes:

| | O2-1 | O2-2 |
|---|---|---|
| Enrollment (PubSub) | 09:42:53 | 10:39:43 |
| Profile job sends the policy | 09:42:57 (+4 s) | 10:39:59 (+16 s) |
| Phone applies it | 09:43:05, on "Registering device..." | 10:40:02, on "Google services" |
| Setup | "Set a new screen lock" | No prompt; home screen with apps blocked |

Device Policy asks for the screen lock only if the password policy is on the phone while it is still registering.
Otherwise setup finishes, `blockAfterDays: 0` blocks the apps ("Action not allowed"), and the only way out is the
"Unblock your apps" notification. That matches the code reading in NOTES.md: the token's default policy has no
password settings, and the 30-second job delivers it. Both outcomes enforce the PIN. The customer's reported failure, a block during setup, hasn't appeared yet.

### F-1: Mac clock 12 s behind (lab)

The Mac's clock was 12.07 s behind (sntp against time.apple.com and Fleet's `Date` header) during O2-1. Watch lines, camera
file names and note times use Mac time. RESULTS.md uses server time (Mac + 12 s). Fix before the next run: turn on
**Set time and date automatically** on the Mac, then re-check with `sntp time.apple.com`.

### F-2: the `fleet_enrolled` activity comes from the Fleet app, not from MDM enrollment

O2-1 logged a global `fleet_enrolled` activity for the Android host at 09:44:13, 80 s after MDM enrollment (09:42:53).
The server log shows `POST /api/fleet/orbit/enroll` at 09:44:13.742 with the host's UUID, then `orbit/config` for the
host: the Fleet app installed during setup enrolled itself. At `fleet-v4.94.0`, `server/service/orbit.go` emits
`ActivityTypeFleetEnrolled` in that orbit enrollment path
([orbit.go#L505-L508](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/service/orbit.go#L505-L508)).
NOTES.md stays correct for MDM enrollment: Android MDM enrollment itself emits no activity. For the option 3
automation, this activity could be a trigger only if every host installs the Fleet app, and it fires after setup
work, not at enrollment.
