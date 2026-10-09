# G-2/G-3: Cloud project, service account, delegation

- **Date:** 2026-10-09
- **Objective:** Create the Google Cloud side of guide Step 2
- **Expected:** Token acting as the admin; devices API reachable

## Steps and evidence
- `01`-`06`: project **fleet-ios-google-lab** created, **Cloud Identity API** enabled, service account **fleet-google-sync** created, its Details tab (the "Unique ID" is the client ID used for delegation), and the Domain-wide delegation page **empty** before the grant.
- `07-token-after-delegation.txt`: the key exchanged for a token acting as the admin. Before the grant the same call returned `FAILED: unauthorized_client - Client is unauthorized to retrieve access tokens using this method, or client not authorized for any of the scopes requested` (seen in the session, not saved as a file).
- `08-google-devices-api.txt`: read-only calls with that token: both lists answer OK with 0 entries, as expected before an iPhone signs in.
- The JSON key and the delegation grant were done by the admin by hand (security steps).

## Result: PASS

Guide findings: first Google Cloud sign-in asks for a country and the Terms of Service; the delegation client ID is the service account's Unique ID; missing delegation shows as `unauthorized_client` and can take a few minutes.
