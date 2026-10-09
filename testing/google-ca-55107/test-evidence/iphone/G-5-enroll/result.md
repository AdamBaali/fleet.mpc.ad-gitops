# G-5: iPhone enrolled in Fleet, end user email set

- **Date:** 2026-10-09
- **Objective:** Enroll a real iPhone in the lab fleet and give the host the managed test user's email
- **Expected:** Host in "iOS Google Lab", MDM on, email in `device_mapping`

## Steps and evidence
- `01`: the fleet's enrollment link opens a page with two tabs, **Personal (BYOD)** and **Company-owned**. Company-owned was selected by default.
- `02`: profile installed (Mobile Device Management + SCEP Device Identity Certificate). Fleet: host in **iOS Google Lab**, `On (manual)` (`03`). iPhone 15 Pro Max, iOS 26.6.1. The tester's own phone, kept (deviation: planned as BYOD).
- `04`: no IdP on the lab Fleet, so the email was set with `PUT /hosts/:id/device_mapping` (`source: custom`). Deviation: the guide expects end user authentication.
- `05`: the sync user (API-only Observer) sees the email through `GET /hosts?device_mapping=true`.

## Result: PASS

Finding: the enroll page defaults to Company-owned, so a tester with a personal phone must pick Personal (BYOD) first.
