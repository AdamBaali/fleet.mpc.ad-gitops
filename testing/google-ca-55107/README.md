# Google conditional access for iPhones (fleetdm/fleet#55107)

Tests the draft guide "Conditional access: Google" and its sync script. Google Context-Aware Access blocks sign-in
from iPhones and iPads that aren't managed by Fleet. Built-in support is tracked in fleetdm/fleet#54888.

- **Plan:** `TEST_PLAN.md`. **Results:** `RESULTS.md`. **Evidence:** `test-evidence/`.
- **Fleet:** `../../fleets/ios-google-lab.yml` ("iOS Google Lab").
- **Google side:** a test Google org and a test organizational unit (OU) only.
- `google-token.sh`: gets a Google access token for the service account, acting as an admin, for local `DRY_RUN`
  runs. The guide doesn't say how. Reads `GOOGLE_SA_KEY_FILE` and `GOOGLE_ADMIN_EMAIL` from `.env`.
