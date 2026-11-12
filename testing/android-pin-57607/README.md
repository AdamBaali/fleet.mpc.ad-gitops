# Android PIN at enrollment: lab (fleetdm/fleet#57607)

Find the best practice, with current Fleet features, to make company-owned (fully managed) Android hosts require a
PIN right after they enroll, ideally before the end user reaches the home screen. For `customer-antonella`, who
enrolls with zero-touch. Background: fleetdm/fleet#57332.

**Status:** done for QR enrollment on one Samsung (2026-11-05). 4 runs of workaround #2: 1 PASS, 3 PARTIAL, PIN
enforced every time, no block during setup. Report draft: [drafts/FINDINGS-COMMENT.md](drafts/FINDINGS-COMMENT.md).
Zero-touch not tested (no zero-touch customer account in the lab).

## What we found

- Fleet sends a host's Android profiles in a per-host policy that a 30-second job assigns after enrollment. The
  enrollment token points at a default policy with no password settings. If the policy reaches the device while
  Android Device Policy is still registering it, setup asks for the PIN (O2-1). If it arrives later, setup finishes
  and `blockAfterDays: 0` blocks the apps at the home screen until a PIN is set (O2-2 to O2-4).
- A `shortSupportMessage` profile replaces the text of the blocked-app dialog, so the end user knows to tap the
  "Unblock your apps" notification (O2-3, O2-4).
- Apps unblock about 3 seconds after the PIN is set. Android Device Policy lifts the block on the phone; Fleet
  sends nothing (F-5).
- Details: [RESULTS.md](RESULTS.md) (findings F-1 to F-5), [NOTES.md](NOTES.md) (code and API sources),
  [EVIDENCE.md](EVIDENCE.md) (every run, with photos).

## Files

| File | What |
|---|---|
| [TEST-PLAN.md](TEST-PLAN.md) | Scope, setup, the O2 runs, what to record, later zero-touch runs |
| [RESULTS.md](RESULTS.md) | Per-run results and findings |
| [EVIDENCE.md](EVIDENCE.md) | Generated index of every test with its result, photos and raw output |
| [NOTES.md](NOTES.md) | Fleet and Google facts with sources, product ask, lab versus production |
| [HANDOFF.md](HANDOFF.md) | State, next steps, teardown |
| [drafts/FINDINGS-COMMENT.md](drafts/FINDINGS-COMMENT.md) | Report for fleetdm/fleet#57607. Posted 2026-11-05; update it after the Pixel runs |
| [tools/run.sh](tools/run.sh) | One test run with the framework helpers (`start`, `watch`, `host`, `activity`, `logs`, `note`, `verdict`) |
| [tools/guide.sh](tools/guide.sh) | On-screen steps, a countdown to the QR scan, and a running clock for the person at the phone |
| [tools/trigger-loop.sh](tools/trigger-loop.sh) | Runs Fleet's Android profile job every 2 s during a run, so the policy reaches the phone early (T runs) |
| [tools/watch-host.sh](tools/watch-host.sh) | Read-only timeline of one host: fleet, labels, profile status |
| [tools/fleet-activity.sh](tools/fleet-activity.sh) | Fleet activity log for one host since a run started: host, upcoming, and global activities that name it |
| [tools/server-logs.sh](tools/server-logs.sh) | Fleet server logs from Render for a run's window, Android lines only, IP addresses masked. Needs `render login` and `RENDER_SERVICE_ID` |
| [tools/cam-log.sh](tools/cam-log.sh) | One frame a second of the phone screen from the iPhone (Continuity Camera), UTC file names, to `private/cam/<ID>/`. adb can't see the setup wizard |
| [tools/cam-preview.sh](tools/cam-preview.sh) | Live preview of the same camera, to line it up on the phone |
| [tools/setup-check.sh](tools/setup-check.sh) | Read-only checks for S-1 to S-3: version, fleets, profiles, label, Android MDM and labels exception |
| [tools/host-fields.py](tools/host-fields.py) | Keeps only the host fields the plan records, so evidence holds no IP addresses |
| `private/` | Internal links and names, camera frames (git ignores it). `private/fleet.env` holds the API token and Render service ID |

GitOps files (outside this folder):

| File | What |
|---|---|
| [`lib/android/configuration-profiles/pin-block-0.json`](../../lib/android/configuration-profiles/pin-block-0.json) | Device PIN, 6+ digits, `NUMERIC_COMPLEX`, block at once, wipe after 30 days (FRP kept) |
| [`lib/android/configuration-profiles/pin-unblock-message.json`](../../lib/android/configuration-profiles/pin-unblock-message.json) | `shortSupportMessage` telling the end user how to unblock apps |
| [`fleets/android-pin-test-block0.yml`](../../fleets/android-pin-test-block0.yml) | The test fleet |

The profiles live in `lib/` rather than here because the apply workflow ignores changes under `testing/`: an edit to
a profile in this folder wouldn't reach Fleet until the nightly run.

## Use it

```bash
# once: private/fleet.env with FLEET_URL and FLEET_API_TOKEN
tools/run.sh start O2-1 "option 2 normal pace" "PIN prompt in setup" "PIN prompt, no block"
tools/run.sh watch O2-1 <serial>                                   # second terminal, before the QR scan
tools/run.sh activity O2-1 <serial>                                 # after the run: Fleet activity log
tools/run.sh logs  O2-1                                            # after the run: server logs from Render
tools/run.sh note  O2-1 "- **PIN prompt in setup:** yes, screen lock step"
tools/run.sh verdict O2-1 PASS "PIN asked in setup, no block"
python3 ../_framework/bin/build-evidence-index.py . "Android PIN at enrollment" \
  test-evidence/S:"Setup" test-evidence/O2:"Option 2"
```

No secrets, device serials or customer names are in this folder. Masking serials needs the `LAB_DEVICE_SECRET_*`
lines described in TEST-PLAN.md S-3.
