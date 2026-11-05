# Handoff: Android PIN at enrollment (fleetdm/fleet#57607)

## State
Done for QR enrollment (2026-11-05). S-1 to S-3 PASS. O2-1 PASS, O2-2 to O2-4 PARTIAL: PIN enforced every time, no
block during setup. Fleet 14 (`android-pin-test-block0`) holds `pin-block-0.json` and `pin-unblock-message.json`.
The report is in `drafts/FINDINGS-COMMENT.md`, not posted. The test phone is enrolled as host 34 with a PIN set.

## Next steps
1. Adam posts `drafts/FINDINGS-COMMENT.md` on fleetdm/fleet#57607.
2. Ask the customer for device models, Android versions, their current profile, and a photo of the setup block.
3. Zero-touch runs (Z) once the lab has a zero-touch customer account.
4. Check the unblock message on a Pixel if one is available.

## Running services
None. `FLEET_LOGGING_DEBUG` was removed from Render on 2026-11-05.

## Teardown
- Remove `fleets/android-pin-test-block0.yml` and `lib/android/configuration-profiles/pin-*.json` through a PR.
- Done 2026-11-05: deleted the 3 unused enroll secrets, removed `FLEET_LOGGING_DEBUG` from Render, deleted `private/cam/`.
- At full teardown: delete `FLEET_ANDROID_PIN_TEST_BLOCK0_ENROLL_SECRET` and its `env` line.
- Remove the phone from Google Drive's USB devices.
- Wipe the test devices and delete them from Fleet.
- Log out of the fleetctl session whose token is in `private/fleet.env`, or revoke the API-only user's token if one replaces it.
- Remove the zero-touch configurations and the test device registration, if made.

## Rules learned
- Wipe with `fleetctl mdm wipe`, then delete the host, so each run is a new host.
- Check the Mac clock before a run (`sntp time.apple.com`).
- A QR enrollment token lasts 1 hour and works once. Reload the enrollment page for each run.
