# Guide findings: Conditional access: Google (draft PR fleetdm/fleet#55107)

What the lab showed so far, with evidence in `test-evidence/`. Test IDs are from `TEST_PLAN.md`. Status: setup and access level done, device tests not run yet (needs an iPhone).

| # | Step | Finding | Proposed edit |
| --- | --- | --- | --- |
| 1 | Prerequisites | Context-Aware Access needs Enterprise Standard or Plus, Education Standard or Plus, Frontline Standard or Plus, Enterprise Essentials Plus, or Cloud Identity Premium. A Business Plus org (the default trial) doesn't have the page. Verified in the Admin console (G-1). | Add: "If you don't see **Context-Aware Access** under **Security**, your edition doesn't include it." |
| 2 | Prerequisites | Right after upgrading Business Plus to Enterprise Standard, the Security menu list was unchanged for about an hour, but the page itself (`Security > Context-Aware Access`) loaded and was "ON for everyone" (G-8). | Tell admins to wait, or give the page URL path |
| 3 | Prerequisites | Gmail needs the primary domain's MX records. A test org that can't change MX can't use Gmail, only Drive and the Google app. | Say Drive works for the test |
| 4 | Step 4 | A newly assigned access level starts in monitor mode and blocks nothing (Google's Deploy Context-Aware Access page). | Add: select **Active** |
| 5 | Step 4 | The condition `device.vendors["<customer-ID>-fleet"].is_managed_device == true` is accepted by Google's Advanced mode editor (G-8). Whether the vendor key resolves is tested with a real device. | Keep, confirm in C-1 |
| 6 | Step 1 to 3 | Not tested yet | |

Not yet tested: the sync script against Google, the GitHub Actions workflow, the iPhone sign-in and block (C-1 to C-4).
