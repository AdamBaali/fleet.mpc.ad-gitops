# G-7: the sync as a GitHub Action

- **Date:** 2026-10-09
- **Objective:** Run the sync from GitHub Actions as the guide's Step 3.4 describes
- **Expected:** Job succeeds, state written or unchanged

## Steps and evidence
- Workflow: `../../../../.github/workflows/google-sync.yml` (manual, `dry_run` input). Secrets: `GOOGLE_SYNC_FLEET_API_TOKEN`, `GOOGLE_CREDENTIALS`, `GOOGLE_ADMIN_EMAIL`, `GOOGLE_CUSTOMER_ID`, `FLEET_URL`.
- Runs 37921809581, 37921848483, 37922082418, with the guide's step `google-github-actions/auth@v2` (`credentials_json`, `token_format: access_token`, `access_token_subject`): **failed at the auth step**: "failed to generate Google Cloud Domain Wide Delegation OAuth 2.0 Access Token: failed to call https://oauth2.googleapis.com/token: HTTP 400: invalid_request". The script never ran. The same key and admin work outside GitHub.
- The action's README says token generation with a key needs `roles/iam.serviceAccountTokenCreator` on the service account; the guide doesn't mention it. Not tested.
- Workaround: sign the delegation JWT in the job with openssl and jq (commit `04848a9`). Runs 37923361720 (`02`), 37923439163, 37923458090: **success**, token step OK, sync exit 0, no output (state already MANAGED).

## Result: PARTIAL

Works with the workaround; fails as the guide writes it.
