# Notes (#46924)

## From the thread
- Customers: eponym, juliana, abstracta, camelot (labels). abstracta sees "software installation failed" in activities when the lid is closed overnight (GrayW, 2026-06-15).
- Noah (2026-07-07) wants fleetd logs for installs and script runs, for story #48898. ddribeiro asked Adam to test (2026-07-08).
- robbiet480 (2026-10-06): Fleet 4.92.3, fleetd 1.61.0, macOS 26 to 27, GCS presigned URLs. About 125 hosts over 10 days, all policy automations. Downloads start in a DarkWake, the Mac sleeps 2 to 5 s later, and the next DarkWake about 16 min on finds the connection reset. The server fallback runs in the same DarkWake and dies the same way. Load balancer: 72% of fallbacks ended `client_disconnected_after_partial_response`.
- Their proposed fixes: defer installs and scripts during DarkWake, hold an `IOPMAssertion` for the download and install, or retry the presigned URL with an HTTP `Range` resume.
- Related: #47851 (86 of 220 Chrome patch failures, same error), #52697.

## Open questions
- Does a script run fail the same way, or does it pause and resume across wakes (PN-3)?
- Does fleetd run at all in DarkWake when Power Nap is off (PN-5)?
- When does the policy automation try again after a download failure? Answered by PN-6: one retry, queued at the failure, which ran 50 s after a full wake and not in the DarkWakes before it.
- Can a report on the `pmset` table spot hosts with Power Nap on, as a stopgap? Yes for one host: the `Power Nap test - pmset settings` query returns `powernap` per power source (B-1, live query). Not tried across a fleet.

## Lab versus production
- One MacBook Air, not a fleet. No presigned URLs, so the URL-then-Fleet fallback isn't exercised (out of scope).
- Lab network and Fleet server behind the lab's tunnel, not a corporate load balancer.
- Needs real hardware. A VM doesn't do Power Nap or clamshell sleep.
