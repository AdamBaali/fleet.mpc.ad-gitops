# Handoff: Android PIN at enrollment (fleetdm/fleet#57607)

## State
Fleet 14 (`android-pin-test-block0`) holds the PIN profile. S-1 to S-3 passed. O2-1 PASS, O2-2 PARTIAL (2026-11-05).
Option 3 fleets removed (scope is option 2). `private/fleet.env` holds an admin session token from fleetctl and the
Render service ID. Fleet on Render runs with `FLEET_LOGGING_DEBUG=true`.

## Next steps
1. O2-3 to O2-5 (fast, fast, slow). First run with `pin-unblock-message.json`.
2. Fill RESULTS.md, build EVIDENCE.md, fill `drafts/FINDINGS-COMMENT.md`.
3. Zero-touch runs (Z): blocked until the lab has a zero-touch customer account.

## Running services
None.

## Teardown
- Remove `fleets/android-pin-test-block0.yml` and `lib/android/configuration-profiles/pin-*.json` through a PR.
- Delete the repository secrets `FLEET_ANDROID_PIN_*_ENROLL_SECRET` and the remaining `env` line.
- Remove `FLEET_LOGGING_DEBUG` from the Render service.
- Remove the phone from Google Drive's USB devices.
- Wipe the test devices and delete them from Fleet.
- Log out of the fleetctl session whose token is in `private/fleet.env`, or revoke the API-only user's token if one replaces it.
- Remove the zero-touch configurations and the test device registration, if made.

## Rules learned
- Wipe with `fleetctl mdm wipe`, then delete the host, so each run is a new host.
- Check the Mac clock before a run (`sntp time.apple.com`).
- A QR enrollment token lasts 1 hour and works once. Reload the enrollment page for each run.
