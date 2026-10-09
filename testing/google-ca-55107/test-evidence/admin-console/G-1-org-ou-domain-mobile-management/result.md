# G-1: Google test org, OU, domain, mobile management

- **Date:** 2026-10-09
- **Objective:** Prepare the Google side the guide assumes
- **Expected:** OU exists, primary domain verified, iOS mobile management is Basic

## Steps and evidence
- `01-ou-fleet-ios-test-created.png`: OU "Fleet iOS test" created under the org.
- `02-domains-primary-verified.png`: primary domain Verified. "Email setup: Action needed" only means MX records are not set. Gmail is not activated, so Drive is used for sign-in tests.
- `03-mobile-management-ios-basic.png`: Mobile Management is Custom with iOS **Basic (agentless)**, what the guide needs. No change made.

## Result: PASS

Guide findings: Gmail needs MX records on the primary domain, so a test org that can't change DNS can only test Drive and the Google app.
