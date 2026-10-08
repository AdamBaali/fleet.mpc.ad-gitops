# Results: #17933 (log, newest last)

## G-1 Google test org setup (2026-10-09, via Claude in Chrome, Admin console signed in as the org admin)
Evidence: `test-evidence/admin-console/G-1-setup/`. The admin account email is not in these pictures.
- OU **Fleet iOS test** created under MPC (01). PASS.
- Domain `mpc.ad`: primary, **Verified** (02). No DNS change was needed. Email setup shows "Action needed", which only means
  MX records are missing. Home page says "You haven't activated Gmail yet": Gmail activation needs MX records, so Gmail
  can't be used on `mpc.ad` without breaking the lab's Cloudflare Email Routing. Drive can be used for the tests.
- iOS mobile management is **Basic (agentless)** already (03). Android Basic, Google Sync Unmanaged. No change made.
- Test users: the "Add new users" form is filled in (managed-test, unmanaged-test @mpc.ad) and waits for the admin to
  finish it. Not created yet (Claude doesn't create accounts or set passwords).
- **BLOCKER (G-8): Context-Aware Access isn't available.** The subscription is **Google Workspace Business Plus** (trial, paid
  service starts 22 Oct 2026, 1 licence assigned, 10 licence limit). Under Security > Access and data control the menu has
  API controls, Data classification, Label Manager, Data protection, Google session control, Google Cloud session
  control and External sharing, with no Context-Aware Access (04). Google's edition list for Context-Aware Access:
  Enterprise Standard and Plus, Education Standard and Plus, Frontline Standard and Plus, Enterprise Essentials Plus,
  Cloud Identity Premium. Business Plus isn't on it. Needs an upgrade to Enterprise Standard (Admin console > Billing >
  Buy or upgrade), paid by Adam.
- Guide finding to add: the guide's prerequisites say "Google Workspace Enterprise Standard, Enterprise Plus, ...". True, and a
  trial Business Plus org can't do the test. Say how to check: the Context-Aware Access page must exist in the menu.

## G-1b Upgrade to Enterprise Standard (2026-10-09)
Adam upgraded the subscription himself. Subscriptions page now shows **Google Workspace Enterprise Standard**, status Active,
1 licence assigned, Flexible plan, "Paid service starts in 13 days" (still inside the trial period), 10 licence limit.
Right after the upgrade, **Context-Aware Access is still missing** from Security > Access and data control, and the URLs
`/ac/security/cloudaccess` and `/ac/security/contextawareaccess` return 404. Likely edition propagation delay. Re-check later
(Google may take hours). If it never appears, check the licence assigned to the admin and the Cloud Identity edition.

## G-8 Context-Aware Access and the access level (2026-10-09)
Evidence: `test-evidence/admin-console/G-8-access-level/`. The CEL condition picture contains the customer ID and is kept private.
- **Context-Aware Access is available** after the Enterprise Standard upgrade: Security > Context-Aware Access, status "ON for everyone" (01).
  The page URL is `/ac/security/context-aware`. It did NOT show in the left menu list during the first hour after the upgrade
  (menu lists were identical to Business Plus), so the guide shouldn't tell admins to find it only through the menu without a
  fallback. (Finding.)
- Access level **Fleet managed iOS** created in **Advanced** mode (02, 03). Condition:
  `device.vendors["<customer-ID>-fleet"].is_managed_device == true`. Google accepted the CEL. PASS (syntax). Whether the
  vendor key resolves is tested in C-1 with a real device state.
- Assign to apps: the page lists "Showing access level assignments in MPC" with the OU tree, and a notice "Context-aware access
  is only available for users who have a licence for some Google Workspace and Cloud Identity editions" (04). The assignment to
  the **Fleet iOS test** OU for Drive and Docs was NOT done by Claude. The click was blocked by the permission classifier
  (granting permissions), so it is left for Adam.
- Per Google's docs (Deploy Context-Aware Access): a newly assigned level starts in **monitor mode** and blocks nothing until it is
  switched to active. The guide's Step 4 doesn't say this. Finding, proposed edit: add "Select **Active**, not monitor".
- The guide's test table (Step 5) can use Drive. Gmail is not activated on `mpc.ad` (needs MX).
