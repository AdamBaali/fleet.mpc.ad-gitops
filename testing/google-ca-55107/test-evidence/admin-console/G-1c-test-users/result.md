# G-1c: test users

- **Date:** 2026-10-09
- **Objective:** Create two users to test managed and unmanaged sign-in
- **Expected:** Both users exist in the test OU

## Steps and evidence
- `01-users-added-passwords-masked.png`: managed-test and unmanaged-test created, generated passwords masked.
- `02-users-moved-to-fleet-ios-test.png`: both moved into the OU "Fleet iOS test" ("2 users have been moved").

## Result: PASS

Note: the Continue button stayed disabled until each email field showed "Available". Setting a field through a form tool did not trigger the check; retyping it did.
