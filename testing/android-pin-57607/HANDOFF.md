# Handoff: Android PIN at enrollment (fleetdm/fleet#57607)

## State
Plan, profiles, fleets, tools and drafts are written on branch `android-pin-57607`. Nothing is applied to the lab
Fleet yet. No device runs. The scripts were tested against a local mock of the Fleet API only.

## Next steps
1. Add four repository secrets and the matching `env` lines in `.github/workflows/workflow.yml`:
   `FLEET_ANDROID_PIN_TEST_BLOCK0_ENROLL_SECRET`, `FLEET_ANDROID_PIN_STAGING_ENROLL_SECRET`,
   `FLEET_ANDROID_PIN_ENFORCED_ENROLL_SECRET`, `FLEET_ANDROID_PIN_LABEL_ENROLL_SECRET`.
2. Open the PR. The CI dry run is the Fleet-side validation of the profiles and the label. If it fails on the label
   (labels exception on), remove `fleets/android-pin-label.yml` and create the label in the UI.
3. Merge, then run TEST-PLAN.md S-1 to S-5, O2-1 to O2-5, O3F, O3L.
4. Fill RESULTS.md, build EVIDENCE.md, fill `drafts/FINDINGS-COMMENT.md`.
5. Zero-touch runs (Z) with a device registered through OEM Test Reseller.

## Running services
None.

## Teardown
- Remove `fleets/android-pin-*.yml` and `lib/android/configuration-profiles/pin-*.json` through a PR. GitOps deletes
  the fleets and the label.
- Delete the four repository secrets and their `env` lines.
- Wipe the test devices and delete them from Fleet.
- Revoke the API-only user's token in `private/fleet.env`.
- Remove the zero-touch configurations and the test device registration, if made.

## Rules learned
- Remove the `android-pin-ready` label before wiping a device. It survives re-enrollment.
- A QR enrollment token lasts 1 hour and works once. Reload the enrollment page for each run.
