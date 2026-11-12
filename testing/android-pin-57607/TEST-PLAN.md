# Test plan: require a PIN when company-owned Android hosts enroll (fleetdm/fleet#57607)

Issue: [fleetdm/fleet#57607](https://github.com/fleetdm/fleet/issues/57607) (CSA task, P1, `customer-antonella`).
Background: [fleetdm/fleet#57332](https://github.com/fleetdm/fleet/issues/57332). Lab: `https://fleet.mpc.ad`.
Results go in [RESULTS.md](RESULTS.md). Research and caveats are in [NOTES.md](NOTES.md).

## Scope

The issue asks to test workaround #2 from fleetdm/fleet#57332: the password profile in the enrollment fleet with
`blockAfterDays: 0`, plus end user instructions for when setup is blocked. It names BlockAction as the fallback if #2
doesn't work, and `pin-block-0.json` already uses it. So this plan is the O2 runs. The option 3 fleets (enroll to a
staging fleet, then move or label) were removed on 2026-11-05: they only matter if option 2 strands end users in setup.

## Question

Using only current Fleet features, what is the most reliable way to make a company-owned (fully managed) Android
host require a screen lock (PIN) right after it enrolls, ideally before the end user reaches the home screen?

The customer enrolls with zero-touch. This plan uses QR enrollment, which is faster to repeat in the lab. Zero-touch
confirmation is a later phase (Z tests). Both methods create an enrollment token that points at the same default
policy (see "Why it is intermittent"), so QR results should carry over. The Z tests check that.

## Why it is intermittent (hypothesis from the code)

Code at the `fleet-v4.94.0` tag:

1. The enrollment token for a QR or zero-touch enrollment always names Fleet's default policy (`policies/1`), not the
   host's fleet profiles ([service.go#L689-L698](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/mdm/android/service/service.go#L689-L698),
   [ee service.go#L128-L134](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/ee/server/mdm/android/service.go#L128-L134)).
   The default policy holds only status reporting settings ([service.go#L378-L393](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/mdm/android/service/service.go#L378-L393)).
2. When Google reports the enrollment, Fleet creates the host in the token's fleet. A cron job that runs every 30
   seconds ([cron.go#L2299-L2306](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/cmd/fleet/cron.go#L2299-L2306))
   merges the fleet's profiles into a per-host policy (`policies/<host UUID>`) and moves the device to it
   ([profiles.go#L436-L486](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/mdm/android/service/profiles.go#L436-L486)).
3. So the password requirement reaches the device somewhere between a few seconds and about a minute after
   enrollment, while the setup wizard is on whatever screen the end user reached. With `blockAfterDays: 0` the block
   starts at once. If the wizard is past the point where Android asks for a screen lock, the block can land on a
   later screen (the terms screen) and stop the end user there.

The O2 runs test this: if the hypothesis holds, the outcome depends on which wizard screen the device is on when the
per-host policy arrives. That's why every run records the screen and the time.

Fleet rejects `setupActions` in Android profiles ([android.go#L62](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/fleet/android.go#L62)),
so a profile can't hold the wizard until the policy arrives.

## What's under test

| Fleet | Profiles | What they do |
|---|---|---|
| `android-pin-test-block0` | `pin-block-0.json` | Device PIN, 6+ digits, `NUMERIC_COMPLEX`. `policyEnforcementRules` blocks at once (`blockAfterDays: 0`) and wipes after 30 days with factory reset protection kept |
| | `pin-unblock-message.json` (from O2-3) | `shortSupportMessage`: tells the end user to tap "Unblock your apps" to set a PIN. Google: shown "wherever functionality has been disabled by the admin". O2-3 checks whether it replaces the "Action not allowed" text |

Profiles are in [`lib/android/configuration-profiles/`](../../lib/android/configuration-profiles/). Google requires
`wipeAction` with every `blockAction`. Without any rule, Google's default blocks at once and wipes after 10 days
without keeping factory reset protection (see NOTES.md).

## Environment

| Item | Value |
|---|---|
| Fleet server | `https://fleet.mpc.ad`, version: record in S-1. Customer's version: record in `private/` |
| Fleet | `android-pin-test-block0` (GitOps `fleets/android-pin-test-block0.yml`) |
| Hosts | Company-owned Android test devices, factory reset before every run. Record model, Android version, security patch |
| Enrollment | QR code from the fleet's company-owned enrollment link. Zero-touch in phase Z |
| Tools | `tools/run.sh` (evidence), `tools/watch-host.sh` (Fleet timeline), `tools/cam-log.sh` and `tools/cam-preview.sh` (iPhone camera), `tools/guide.sh` (steps and countdown), `tools/server-logs.sh` (Render) |
| Lab differences from production | QR, not zero-touch. One or two device models, not the customer's fleet of models. Lab Fleet version may differ from the customer's. No apps deployed, so "work apps" means the apps on the device |

## Setup (S)

| ID | Step | Pass when |
|---|---|---|
| S-1 | GitOps creates the test fleet. Record the Fleet version (`run.sh start` writes it) | `android-pin-test-block0` exists with its profiles |
| S-2 | Confirm Android MDM is on (**Settings > Integrations > MDM**) | Android MDM on |
| S-3 | Create `private/fleet.env` with `FLEET_URL` and `FLEET_API_TOKEN` (an API-only user with maintainer or admin role). To keep device serials out of the public evidence, add `LAB_DEVICE_SECRET_1=<serial>` lines: the framework masks any value whose name contains `SECRET` | `tools/run.sh start S-3 "setup check" "api works" "version shown"` prints a Fleet version |
| S-4 | For each fleet, open **Hosts**, pick the fleet, **Add hosts > Android > Company-owned (fully-managed)**. That option shows a link, not a QR code (only **Personal (BYOD)** shows one). Open the link in a laptop browser: the enrollment page shows the QR code the wiped device scans ([android-mdm-setup.md#L67](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/articles/android-mdm-setup.md?plain=1#L67)) | Enrollment page with a QR code for each fleet. Open it just before each run: the QR's enrollment token lasts 1 hour and works once |
| S-5 | Prepare the device: charged, Wi-Fi details at hand, a second phone or camera to film the screen with a clock in view | A test video shows the screen and a clock |

## What to record per run

Start `tools/run.sh watch <ID> <serial>` and `tools/cam-log.sh <ID>` before scanning the QR code (`tools/cam-preview.sh` to aim the camera). Check the Mac clock first (`sntp time.apple.com`): Mac times go in the evidence. It saves a line with a UTC time each time the
host, its fleet, labels or profile status change. Then fill the RESULTS.md row and add each
field with `tools/run.sh note`.

| Field | How |
|---|---|
| Android version, security patch, device model | Settings > About phone, or `run.sh host` after enrollment |
| New or re-enrolled host | Was the serial in Fleet before the run? (Fleet reuses the host and its per-host policy on re-enrollment) |
| T0: QR scanned | Clock in the video |
| Host appears in Fleet (T+) | First `id=` line in `NN-watch.txt` |
| Profile first Pending, then Verified or Failed (T+) | `NN-watch.txt` |
| Wizard screen when the policy arrived | Video: the screen showing when the device changed (password prompt, block notice, Google services, terms, and so on) |
| PIN prompt during setup | Yes or no, and on which screen |
| "Blocked by your work policy" during setup | Yes or no, on which screen, and the exact text |
| What got the device past a block, if anything | Back button presses, network change, wait, reset |
| Reached home screen (T+) | Video |
| Move or label applied (T+) | `NN-move.txt` (option 3 only) |
| Apps blocked (T+), and which | Open Chrome, Play Store and Camera after the home screen. Record the block screen text |
| PIN prompt or notification after setup (T+) | Video |
| PIN set (T+), and profile status after it | Video, `NN-watch.txt` |
| Notes | Wizard pace, network, anything odd |

## Tests

Common run steps (R):
1. If the device was in a previous run: for the label option, remove the label first (`run.sh move <ID> <serial> --remove-label android-pin-ready`). Manual labels survive a wipe and re-enrollment.
2. Factory reset the device (Settings > System > Reset options > Erase all data, or **Actions > Wipe** in Fleet).
3. `tools/run.sh start <ID> "<title>" "<objective>" "<expected>"`, then `tools/run.sh watch <ID> <serial>` in a second terminal.
4. Open the fleet's company-owned enrollment link in a laptop browser (S-4). On the device welcome screen, tap 6 times to open the QR reader and scan the QR code on that page. Note T0.
5. Go through the wizard at the pace the run asks for. Record every screen and every prompt.
6. After the home screen (or after giving up on a block), open Chrome, Play Store and Camera.
7. Set a PIN when asked. Check the profile status in Fleet. `tools/run.sh host <ID> <serial>`.
8. `tools/run.sh activity <ID> <serial>` and `tools/run.sh logs <ID>` to save Fleet's activity log and the server logs for the run's window.
9. `tools/run.sh note` for each field, then `tools/run.sh verdict <ID> <result> "<one line>"`. Fill the RESULTS.md row.

### Option 2 runs (O2)

Fleet `android-pin-test-block0`. The outcome depends on when Fleet's 30-second profile job sends the policy (O2-1,
O2-2), so vary the pace.

| ID | Pace | Purpose |
|---|---|---|
| O2-1 | Normal | Done: PASS (policy 4 s after enrollment, prompt in setup) |
| O2-2 | Normal | Done: PARTIAL (policy 16 s after enrollment, apps blocked at home) |
| O2-3 | Fast: tap through every screen as soon as it allows | Done: PARTIAL. First run with the unblock message; it showed in the block dialog |
| O2-4 | Fast | Done: PARTIAL. Reworded unblock message showed and led the end user to the PIN |
| O2-5 | Slow: wait 2 minutes on the first input screen after "Getting your phone ready" | Not run: the prompt in setup depends on Fleet's job timing, not on the end user, so waiting isn't an instruction we'd give |
| O2-6+ | Repeat whichever pace gives a FAIL, on a second device model if available | |

Between runs: `fleetctl mdm wipe --host <serial>`, wait for Fleet to show the host wiped, then delete the host so the
next run enrolls as a new host.

Result per run:
- PASS: PIN prompt in setup, no block, home screen with a PIN set.
- PARTIAL: no prompt in setup, but the PIN is still enforced: the end user reaches the home screen with apps blocked
  until a PIN is set. Record how the end user finds the way out (the block dialog, the notification).
- FAIL: the end user is stuck in setup ("blocked by your work policy"), or reaches apps without a PIN.

On a FAIL, try the recovery from #57332 workaround 2 (Back until the QR screen, then try again) and record whether it
works. The goal is how often each outcome happens and whether every outcome ends with the PIN enforced.
(Changed after O2-2: the first rule counted a post-setup block as a failure, but the PIN is still enforced there.)

### Customer's exact profiles (E)

Fleet `android-pin-exact` holds exact copies of the customer's two profiles
([`customer-replica/`](../../lib/android/configuration-profiles/customer-replica/)). They differ from `pin-block-0.json`
in `maximumFailedPasswordsForWipe: 6`, `maximumTimeToLock`, `keyguardDisabledFeatures`, `deviceOwnerLockScreenInfo`,
and no `preserveFrp`. The E runs check whether those settings cause a block during setup on the Samsung. A FAIL here
points at the profile; a PASS or PARTIAL points back at the device.

| ID | Pace | Steps | Pass when |
|---|---|---|---|
| E-1 | Normal | Common run steps, fleet `android-pin-exact` | Same pattern as O2: prompt in setup or apps blocked at home. No block in setup |
| E-2 | Fast | As E-1, tapping through every screen | As E-1 |
| E-3 | Slow | As E-1, but wait 3 minutes on each Google terms screen before accepting (the customer's repro tip) | As E-1 |

Reports from outside the lab, for context (Pixel 10a, a Fleet teammate, same timing split): with `blockAfterDays: 0`
and `BLOCK_SCOPE_DEVICE`, the PIN prompt came after "Registering device" in two runs, and "Blocked by work policy"
showed on "I accept" in the third. With `blockAfterDays: 1`, setup showed a notice and nothing was enforced. The
customer removed `blockScope` and still got the block on a Pixel.

### Trigger runs (T)

Fleet `android-pin-test-block0`. Start `tools/trigger-loop.sh` before the QR scan, so the profile job runs every 2 s
(NOTES.md, "a faster delivery path"). Tests whether an early policy, and so the PIN prompt in setup, can be made
reliable with current Fleet.

| ID | Device | Pace | Pass when |
|---|---|---|---|
| T-1 to T-4 | Samsung | Normal, normal, fast, fast | PIN prompt in setup in all 4 (O2 without the loop: 1 of 4). Record seconds from enrollment to "policy sent" |
| T-5+ | Pixel | Normal, then a 3-minute wait on "Additional legal terms" | PIN prompt in setup, no "Blocked by work policy" |

### Pixel runs (P)

The customer's block happens on Pixels (a Pixel 11 Pro and a Pixel 10a), on the Pixel's "Additional legal terms"
screen. Their tip: wait 3 minutes on that screen so the policy lands first; a fast tap on "I accept" can beat it.
Their screen also shows a Google account, so an account is added during setup. None of the O2 runs added one. The P
runs separate the two variables: the device, and the account.

| ID | Fleet | Steps | Pass when |
|---|---|---|---|
| P-1 | `android-pin-test-block0` | Sign in to a Google account during setup. Wait 3 minutes on "Additional legal terms", then tap "I accept" | No block in setup (PASS or PARTIAL as in O2). FAIL reproduces the customer's block |
| P-2 | `android-pin-test-block0` | Same as P-1, but skip the Google account step | As P-1. Compare with P-1: if only P-1 blocks, the account step is the trigger |
| P-3 | `android-pin-staging` (`pin-block-1.json`), then `android-pin-enforced` (`pin-block-0.json`, unblock message) | Repeat the P-1 steps. After the home screen, move the host with `POST /api/v1/fleet/hosts/transfer` (body `{"fleet_id": <enforced>, "hosts": [<host id>]}`) | No block in setup. After the move, apps are blocked until a PIN is set, and the unblock message shows |

P-3 needs the two fleets back in GitOps (removed in commit 82b293d; see commit 4d69ed3 for the old files). Record
the wizard screen at each minute of the wait, and which screen shows the block.

### Zero-touch confirmation (Z), later

Point a zero-touch configuration at `android-pin-test-block0` (Fleet **Settings > Integrations > MDM > Android
zero-touch** has a fleet picker in 4.94.0). Blocked until the lab has a zero-touch customer account (NOTES.md). Register a test device through **OEM Test Reseller** and Google's form, as the zero-touch
guide describes.

| ID | Steps | Pass when |
|---|---|---|
| Z-1 to Z-3 | Repeat O2 with the zero-touch configuration for `android-pin-test-block0` | Same result pattern as O2 |

## Out of scope

- Personal (BYOD) hosts and work profile password scope.
- Product changes. If no option is reliable, the finding is the product ask in NOTES.md.
- The customer's own profile. If they share it, run O2 once more with it (keep it in `private/`).
