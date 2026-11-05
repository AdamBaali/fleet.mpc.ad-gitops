# Test plan: require a PIN when company-owned Android hosts enroll (fleetdm/fleet#57607)

Issue: [fleetdm/fleet#57607](https://github.com/fleetdm/fleet/issues/57607) (CSA task, P1, `customer-antonella`).
Background: [fleetdm/fleet#57332](https://github.com/fleetdm/fleet/issues/57332). Lab: `https://fleet.mpc.ad`.
Results go in [RESULTS.md](RESULTS.md). Research and caveats are in [NOTES.md](NOTES.md).

## Scope (2026-11-05)

The issue asks to test workaround #2 from fleetdm/fleet#57332: the password profile in the enrollment fleet with
`blockAfterDays: 0`, plus end user instructions for when setup is blocked. It names BlockAction as the fallback if #2
doesn't work. So the O2 runs are the test. Option 3 (O3F, O3L) and the optional runs are not run unless option 2 can
strand an end user in setup. Their fleets stay in GitOps until teardown.

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

## Options under test

| Option | Fleet | Profile | What it does |
|---|---|---|---|
| 1 (baseline, optional) | `android-pin-test-block0` with `pin-block-1.json` swapped in | `blockAfterDays: 1` | Known: no prompt in setup, profile Failed (USER_ACTION), apps open for up to 24 h |
| 2 | `android-pin-test-block0` | `pin-block-0.json` | Profile present at enrollment. Is the PIN prompt in setup reliable? |
| 3, fleet move | `android-pin-staging`, then `android-pin-enforced` | none, then `pin-block-0.json` | Setup finishes with no password policy, then the host moves and is blocked until a PIN is set |
| 3, label | `android-pin-label` | `pin-block-0.json` scoped to manual label `android-pin-ready` | Same as the fleet move, with a label instead |
| Variant (optional) | `android-pin-test-block0` with `pin-blockaction-device.json` swapped in | `blockScope: BLOCK_SCOPE_DEVICE` | Does device-wide block scope change the wizard behavior? |

Profiles are in [`lib/android/configuration-profiles/`](../../lib/android/configuration-profiles/). All three set a
device-scope PIN of at least 6 digits with no repeating or ordered sequences (`NUMERIC_COMPLEX`), and an enforcement
rule for `passwordPolicies`. Google requires `wipeAction` with every `blockAction`, so each rule also wipes after 30
days (factory reset protection kept). Without any rule, Google's default blocks at once and wipes after 10 days
without keeping factory reset protection (see NOTES.md).

## Environment

| Item | Value |
|---|---|
| Fleet | `https://fleet.mpc.ad`, version: record in S-1. Customer's version: record in `private/` |
| Fleets | `android-pin-test-block0`, `android-pin-staging`, `android-pin-enforced`, `android-pin-label` (GitOps `fleets/android-pin-*.yml`) |
| Hosts | Company-owned Android test devices, factory reset before every run. Record model, Android version, security patch |
| Enrollment | QR code from each fleet's enrollment page (company-owned). Zero-touch in phase Z |
| Tools | `tools/run.sh` (framework evidence), `tools/watch-host.sh` (Fleet timeline), `tools/move-host.sh` (option 3 step) |
| Lab differences from production | QR, not zero-touch. One or two device models, not the customer's fleet of models. Lab Fleet version may differ from the customer's. No apps deployed, so "work apps" means the apps on the device |

## Setup (S)

| ID | Step | Pass when |
|---|---|---|
| S-1 | Merge the PR so GitOps creates the four fleets. Record the Fleet version (`run.sh start` writes it) | The four fleets exist. Each Android fleet shows its profile; `android-pin-staging` shows none |
| S-2 | Confirm Android MDM is on (**Settings > Integrations > MDM**) and the labels exception setting under **Settings > Integrations > Change management** | Android MDM on. If the labels exception is on, the PR dry run fails on `android-pin-label.yml`: drop that file and create the label in the UI |
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

### Option 2: profile present at enrollment (O2), at least 5 runs

Fleet `android-pin-test-block0`. Because the hypothesis is a race with the wizard, vary the pace on purpose.

| ID | Pace | Expected if the hypothesis holds |
|---|---|---|
| O2-1 | Normal: continue as soon as each screen allows | Either outcome. Record the screen at policy arrival |
| O2-2 | Normal | Same |
| O2-3 | Normal | Same |
| O2-4 | Slow: the host enrolls once the device finishes setting itself up for the organization (after the QR scan, Wi-Fi and the Android Device Policy download). Wait 2 minutes on the first screen that asks for input after that point, then go on at normal pace | The policy arrives while the wizard waits, so the screen lock step sees it. PIN prompt more likely |
| O2-5 | Fast: tap through every screen after that point as soon as it allows | The policy arrives after the screen lock step. Block on a later screen more likely |
| O2-6+ | Repeat whichever pace gave a mixed result, on a second device model if available | |

Result per run:
- PASS: PIN prompt in setup, no block, home screen with a PIN set.
- PARTIAL: no prompt in setup, but the PIN is still enforced: the end user reaches the home screen with apps blocked
  until a PIN is set. Record how the end user finds the way out (the block dialog, the notification).
- FAIL: the end user is stuck in setup ("blocked by your work policy"), or reaches apps without a PIN.

On a FAIL, try the recovery from #57332 workaround 2 (Back until the QR screen, then try again) and record whether it
works. The goal is how often each outcome happens and whether every outcome ends with the PIN enforced.
(Changed after O2-2: the first rule counted a post-setup block as a failure, but the PIN is still enforced there.)

### Option 3: enroll with no password policy, then enforce (O3F, O3L)

| ID | Steps | Expected | Pass when |
|---|---|---|---|
| O3F-1 to O3F-3 | Enroll with the `android-pin-staging` QR. Finish setup to the home screen. Then `tools/run.sh move <ID> <serial> --fleet android-pin-enforced` | Setup has no PIN prompt and no block. Within about a minute of the move, apps are blocked and Android asks for a screen lock. After the PIN, the profile shows Verified | Setup completes, block and prompt follow the move, profile Verified after the PIN. Record the minutes between home screen and block |
| O3F-4 | Same as O3F-1, but move the host while the wizard is still on the terms screen | Shows what happens if the automation fires too early (same failure as option 2?) | Recorded (INFO) |
| O3L-1, O3L-2 | Enroll with the `android-pin-label` QR. Finish setup. `tools/run.sh move <ID> <serial> --label android-pin-ready` | Same as O3F | Same as O3F |
| O3L-3 | After O3L-2, factory reset without removing the label and enroll again with the `android-pin-label` QR | The label survives, so the profile is present at enrollment: behaves like option 2 | Recorded. Confirms the label caveat in NOTES.md |
| O3F-5 | After O3F-3 (host in `android-pin-enforced`), factory reset and enroll with the `android-pin-staging` QR | Fleet takes the fleet from the enrollment token on re-enrollment ([pubsub.go#L843](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/mdm/android/service/pubsub.go#L843)), so the host lands in staging with no password policy | Host in `android-pin-staging`, no PIN prompt in setup |

### Optional (B1, V)

Both need a change to `fleets/android-pin-test-block0.yml` through a PR: swap the profile path, then swap it back.

| ID | Steps | Expected |
|---|---|---|
| B1-1 | Fleet with `pin-block-1.json`, one run | Reproduces the report: no prompt in setup, profile Failed (USER_ACTION), apps usable |
| V-1 to V-3 | Fleet with `pin-blockaction-device.json`, 3 runs at normal pace | Unknown. Compare with O2: does device-wide scope block the wizard more often or less? |

### Zero-touch confirmation (Z), later

Point a zero-touch configuration at each fleet (Fleet **Settings > Integrations > MDM > Android zero-touch**, one
configuration per fleet). Register a test device through **OEM Test Reseller** and Google's form, as the zero-touch
guide describes.

| ID | Steps | Pass when |
|---|---|---|
| Z-1 to Z-3 | Repeat O2 with the zero-touch configuration for `android-pin-test-block0` | Same result pattern as O2 |
| Z-4, Z-5 | Repeat O3F with the zero-touch configuration for `android-pin-staging` | Same result as O3F |

## Out of scope

- Personal (BYOD) hosts and work profile password scope.
- Product changes. If no option is reliable, the finding is the product ask in NOTES.md.
- The customer's own profile. If they share it, run O2 and O3F once more with it (keep it in `private/`).
