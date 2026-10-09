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

## R-1 Script syntax and lint (2026-10-09): PASS
`docs/solutions/api-scripts/sync-fleet-hosts-to-google.sh` from PR #55107 (83 lines): `bash -n` OK, `shellcheck -S warning` reports nothing.
Read through for R-5: paging, `|| true` around the clientState read (a missing state returns 404, handled), a Google error aborts the run
(`set -euo pipefail`), a removed Fleet host is set UNMANAGED on the next run, ambiguous matches print "Review" and are not marked managed.
Not yet run against live data.

## Fleet side
Local commit in the GitOps repo (not pushed): `fleets/ios-google-lab.yml` ("iOS Google Lab") and the `FLEET_IOS_GOOGLE_LAB_ENROLL_SECRET`
line in `.github/workflows/workflow.yml`. The repo secret doesn't exist yet: `tools/save-secret.sh` style, generate and pipe to
`gh secret set` (needs Adam).

## Open: access level assignment (G-8)
Still not assigned. The permission classifier blocked selecting the OU in the assignment tree twice, even after Adam said go ahead
in chat. It must be done by Adam in the console.

## G-2/G-3 Google Cloud project and service account (2026-10-09, Claude in Chrome)
- Cloud project **fleet-ios-google-lab** created (no organisation parent), **Cloud Identity API enabled** (status Enabled). PASS.
- Service account **fleet-google-sync** created (Enabled). Its client ID (the "Unique ID") is used for domain-wide delegation. PASS.
- NOT done by Claude: the JSON key (blocked by the permission classifier: secret write) and the domain-wide delegation grant (permission grant).
  Adam does both. Key goes to `secrets/google-sa.json` (gitignored).
- Test users: form filled in Admin console, waiting for Adam to click Continue and create.
- Fleet enroll secret for the iOS fleet: script ready (`tools/setup-ios-secret.sh`), the classifier blocks secret writes, Adam runs it.
- Chrome typing notes: typing failed in the Admin console (other extension) but worked in the Cloud console; `form_input` works in the Admin console.

## G-3 Service account key and delegation test (2026-10-09)
- Adam created the JSON key. It is stored in `secrets/google-sa.json` (gitignored, mode 600). Structure checked: service_account, private key present, client ID matches.
- `tools/google-token.sh` (new) signs a JWT with the key and asks Google for a token acting as the admin, scope `cloud-identity.devices`. Writes the token to a file, prints no secrets.
- First run "OK" was a false pass: `.env` had empty values, so no admin was impersonated. Fixed: the helper now refuses an empty admin email.
- Real run: **FAILED: unauthorized_client** ("Client is unauthorized to retrieve access tokens using this method, or client not authorized for any of the scopes requested").
  Meaning: the domain-wide delegation entry is missing or not yet active for this client ID and scope. Next: Adam adds it in
  Admin console > Security > Access and data control > API controls > Domain-wide delegation, then re-run.
- Guide finding: the guide's Step 2 should name this exact error as the symptom of missing delegation, and say the grant can take a few minutes.
- `FLEET_API_TOKEN` is still empty (API-only Fleet user not created yet), so the script's DRY_RUN (G-4) can't run.
