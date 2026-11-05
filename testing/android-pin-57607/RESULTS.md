# Results: require a PIN when company-owned Android hosts enroll (fleetdm/fleet#57607)

Plan: [TEST-PLAN.md](TEST-PLAN.md). Evidence per run: `test-evidence/<group>/<ID>-<slug>/` (build `EVIDENCE.md` with
`testing/_framework/bin/build-evidence-index.py`). Times are UTC. "T+" is minutes and seconds after the QR scan (T0).

Fleet version: 4.94.0 · Enrollment: QR (zero-touch in Z) · Code references: `fleet-v4.94.0`

## Summary

| Option | Runs | Passed | Result | One line |
|---|---|---|---|---|
| 2: profile at enrollment (`android-pin-test-block0`) | 2 | 1 | FAIL so far | PIN prompt in setup only when Fleet's profile job runs before Device Policy finishes registering (O2-1: 4 s, prompt; O2-2: 16 s, no prompt, apps blocked at home) |
| 3: fleet move (`android-pin-staging` -> `android-pin-enforced`) | | | | |
| 3: label (`android-pin-label` + `android-pin-ready`) | | | | |
| 1: `blockAfterDays: 1` (optional) | | | | |
| Variant: `BLOCK_SCOPE_DEVICE` (optional) | | | | |
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
| O2-3 | | | | | | Normal | | | | | | | | |
| O2-4 | | | | | | Slow | | | | | | | | |
| O2-5 | | | | | | Fast | | | | | | | | |
| O3F-1 | | | | | | Normal | | | | | | | | |
| O3F-2 | | | | | | Normal | | | | | | | | |
| O3F-3 | | | | | | Normal | | | | | | | | |
| O3F-4 | | | | | | Move on terms screen | | | | | | | | |
| O3F-5 | | | | | | Normal, staging QR after enforced | | | | | | | | |
| O3L-1 | | | | | | Normal | | | | | | | | |
| O3L-2 | | | | | | Normal | | | | | | | | |
| O3L-3 | | | | | | Normal, label kept | | | | | | | | |
| B1-1 | | | | | | Normal | | | | | | | | |
| V-1 | | | | | | Normal | | | | | | | | |
| Z-1 | | | | | | Normal | | | | | | | | |

## Runs: enforcement after setup

| ID | Fleet at enrollment | Move or label applied (T+) | Apps blocked (T+) | Apps blocked (which) | PIN prompt or notice after setup (T+) | PIN set (T+) | Profile status after PIN (T+) | Minutes usable without a PIN | Result | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| O2-1 | `android-pin-test-block0` | n/a | Not tested: PIN set before the home screen | n/a | 09:43:05, in setup | 09:43:37 | Verified 09:43:43 | 0 | PASS | [O2-1](test-evidence/O2/O2-1-option-2-normal-pace/result.md) |
| O2-2 | `android-pin-test-block0` | n/a | 10:42:00 (at the home screen) | All but Phone and Play Store: "Action not allowed... Contact your organisation's IT administrator" | Notification only, no screen | 10:45:48 | Verified 10:45:53 | 0 (blocked until the PIN) | FAIL | [O2-2](test-evidence/O2/O2-2-option-2-normal-pace/result.md) |
| O2-3 | `android-pin-test-block0` | n/a | | | | | | | | |
| O2-4 | `android-pin-test-block0` | n/a | | | | | | | | |
| O2-5 | `android-pin-test-block0` | n/a | | | | | | | | |
| O3F-1 | `android-pin-staging` | | | | | | | | | |
| O3F-2 | `android-pin-staging` | | | | | | | | | |
| O3F-3 | `android-pin-staging` | | | | | | | | | |
| O3F-4 | `android-pin-staging` | | | | | | | | | |
| O3F-5 | `android-pin-staging` | n/a | | | | | | | | |
| O3L-1 | `android-pin-label` | | | | | | | | | |
| O3L-2 | `android-pin-label` | | | | | | | | | |
| O3L-3 | `android-pin-label` | label kept | | | | | | | | |
| B1-1 | `android-pin-test-block0` (block 1) | n/a | | | | | | | | |
| V-1 | `android-pin-test-block0` (device scope) | n/a | | | | | | | | |
| Z-1 | zero-touch: | | | | | | | | | |

Add a row to both tables for each extra run (O2-6, V-2, Z-2, and so on).

## Findings

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
password settings, and the 30-second job delivers it. Option 2 fails the plan's rule (every run must pass).

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
