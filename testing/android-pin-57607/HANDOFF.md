# Handoff: Android PIN at enrollment (fleetdm/fleet#57607)

## State
Fleets 11 to 14, their profiles and the `android-pin-ready` label are applied to the lab Fleet (4.94.0, Android MDM
on). The four enroll secrets are repository secrets. S-1 to S-3 passed on 2026-11-05. No device runs yet.
`private/fleet.env` holds an admin session token from fleetctl, which expires with that session.

## Next steps
1. S-4: open the company-owned QR page for each fleet. S-5: camera and clock check.
2. Run O2-1 to O2-5, O3F-1 to O3F-3, O3F-5, O3L-1 to O3L-3.
3. Fill RESULTS.md, build EVIDENCE.md, fill `drafts/FINDINGS-COMMENT.md`.
4. Zero-touch runs (Z). Blocked: the lab Google account has no zero-touch customer account (the portal returns 403),
   and only a reseller can create one. See NOTES.md.

## Running services
None.

## Teardown
- Remove `fleets/android-pin-*.yml` and `lib/android/configuration-profiles/pin-*.json` through a PR. GitOps deletes
  the fleets and the label.
- Delete the four repository secrets and their `env` lines.
- Wipe the test devices and delete them from Fleet.
- Log out of the fleetctl session whose token is in `private/fleet.env`, or revoke the API-only user's token if one replaces it.
- Remove the zero-touch configurations and the test device registration, if made.

## Rules learned
- Remove the `android-pin-ready` label before wiping a device. It survives re-enrollment.
- A QR enrollment token lasts 1 hour and works once. Reload the enrollment page for each run.
