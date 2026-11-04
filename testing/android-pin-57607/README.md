# Android PIN at enrollment: lab (fleetdm/fleet#57607)

Find the best practice, with current Fleet features, to make company-owned (fully managed) Android hosts require a
PIN right after they enroll, ideally before the end user reaches the home screen. For `customer-antonella`, who
enrolls with zero-touch. Background: fleetdm/fleet#57332.

**Status:** plan ready, no runs yet. Start with [TEST-PLAN.md](TEST-PLAN.md).

## What we know before testing

- Fleet sends a host's Android profiles in a per-host policy that a 30-second job assigns after enrollment. The
  enrollment token itself points at a default policy with no password settings. So with `blockAfterDays: 0`, the block
  lands on whatever setup screen the end user reached. This likely explains the intermittent "blocked by your work
  policy". Details and code links: [NOTES.md](NOTES.md).
- A fleet move (option 3) resets on a wipe, because the enrollment configuration sets the fleet. A manual label
  doesn't: it stays on the host.

## Files

| File | What |
|---|---|
| [TEST-PLAN.md](TEST-PLAN.md) | Setup, runs for options 2 and 3 with QR enrollment, what to record, later zero-touch runs |
| [RESULTS.md](RESULTS.md) | Empty results tables that match the plan |
| [NOTES.md](NOTES.md) | Fleet and Google facts with sources, product ask, lab versus production |
| [HANDOFF.md](HANDOFF.md) | State, next steps, teardown |
| [drafts/FINDINGS-COMMENT.md](drafts/FINDINGS-COMMENT.md) | Draft comment for fleetdm/fleet#57607 with placeholders. Not posted |
| [tools/run.sh](tools/run.sh) | One test run with the framework helpers (`start`, `watch`, `host`, `move`, `note`, `verdict`) |
| [tools/watch-host.sh](tools/watch-host.sh) | Read-only timeline of one host: fleet, labels, profile status |
| [tools/move-host.sh](tools/move-host.sh) | Option 3 step: move a host by serial to a fleet, or add or remove a manual label. Dry run unless `--apply` |
| [tools/host-fields.py](tools/host-fields.py) | Keeps only the host fields the plan records, so evidence holds no IP addresses |
| `private/` | Internal links and names (git ignores it). `private/fleet.env` holds the API token |

GitOps files (outside this folder):

| File | What |
|---|---|
| [`lib/android/configuration-profiles/pin-block-0.json`](../../lib/android/configuration-profiles/pin-block-0.json) | Device PIN, 6+ digits, `NUMERIC_COMPLEX`, block at once, wipe after 30 days (FRP kept) |
| [`lib/android/configuration-profiles/pin-block-1.json`](../../lib/android/configuration-profiles/pin-block-1.json) | Same, block after 1 day (baseline, not used by a fleet) |
| [`lib/android/configuration-profiles/pin-blockaction-device.json`](../../lib/android/configuration-profiles/pin-blockaction-device.json) | Same as block 0, with `blockScope: BLOCK_SCOPE_DEVICE` (optional variant, not used by a fleet) |
| [`fleets/android-pin-test-block0.yml`](../../fleets/android-pin-test-block0.yml) | Option 2 |
| [`fleets/android-pin-staging.yml`](../../fleets/android-pin-staging.yml) | Option 3, enrollment fleet with no password profile |
| [`fleets/android-pin-enforced.yml`](../../fleets/android-pin-enforced.yml) | Option 3, target fleet |
| [`fleets/android-pin-label.yml`](../../fleets/android-pin-label.yml) | Option 3 with a manual label instead of a fleet move |

The profiles live in `lib/` rather than here because the apply workflow ignores changes under `testing/`: an edit to
a profile in this folder wouldn't reach Fleet until the nightly run.

## Use it

```bash
# once: private/fleet.env with FLEET_URL and FLEET_API_TOKEN
tools/run.sh start O2-1 "option 2 normal pace" "PIN prompt in setup" "PIN prompt, no block"
tools/run.sh watch O2-1 <serial>                                   # second terminal, before the QR scan
tools/run.sh move  O3F-1 <serial> --fleet android-pin-enforced     # option 3, after the home screen
tools/run.sh note  O2-1 "- **PIN prompt in setup:** yes, screen lock step"
tools/run.sh verdict O2-1 PASS "PIN asked in setup, no block"
python3 ../_framework/bin/build-evidence-index.py . "Android PIN at enrollment" \
  test-evidence/O2:"Option 2" test-evidence/O3F:"Option 3, fleet move" test-evidence/O3L:"Option 3, label"
```

No secrets, device serials or customer names are in this folder. Masking serials needs the `LAB_DEVICE_SECRET_*`
lines described in TEST-PLAN.md S-3.
