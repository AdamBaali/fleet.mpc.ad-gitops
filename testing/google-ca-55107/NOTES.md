# Notes: how the lab differs from production

- **Google:** Workspace Enterprise Standard trial on a lab domain. Context-Aware Access assigned to the test OU **Fleet iOS test**
  only, for Drive and Docs and Gmail. Nothing at the top-level OU.
- **Apps:** Drive and the Google sign-in pages. Gmail can't be activated without MX records on the lab domain.
- **iPhone:** the tester's own iPhone 15 Pro Max (iOS 26.6.1), enrolled with the fleet's enrollment link as company-owned
  (`On (manual)`), not through Apple Business (ADE).
- **End user email:** the lab has no end user authentication. The email was first a custom mapping, then an IdP username set
  with `PUT /api/v1/fleet/hosts/:id/device_mapping` (`source: idp`). Fleet reports that as `mdm_idp_accounts`, the same source
  end user authentication fills, so the script took the customer's path. ADE with end user authentication itself wasn't run.
- **Two users:** a managed test user (Fleet email) and an unmanaged one (no Fleet host), both in the test OU, on the same iPhone.
- **Sync:** the GitHub Action in this public repo, masked logs. Every sync in the tests was started by hand: GitHub started this
  repo's scheduled runs hours late or not at all.
- **Fleet API token:** an API-only Observer user limited to List hosts (G-2b).
- **Domain-wide delegation:** the service account acts as a super admin. A delegated admin with mobile rights only wasn't tried.
- **Evidence rules:** window-only screenshots; emails, Google IDs and the serial number masked; frames that showed personal
  accounts or the home screen removed. No secrets in the repo.
