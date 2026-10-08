# Services Context-Aware Access can protect (this org, 2026-10-09)
Source: Security > Context-Aware Access > Assign access levels, "Apps" list. Pictures: `test-evidence/admin-console/G-8-access-level/05` and `06`.
All entries use the **Continuous** evaluation point. Counts are from the MPC (top level) view.

| App | Active levels | Notes |
| --- | --- | --- |
| Admin Console | **1** | Shown separately above the table |
| Calendar | 0 | |
| Chrome Remote Desktop | 0 | |
| Classroom | 0 | |
| Cloud Search | 0 | |
| Data Studio | 0 | |
| Drive and Docs | **1** | In the guide's Step 4 |
| Gemini Enterprise | 0 | |
| Gemini Notebook | 0 | |
| Gemini app | 0 | |
| Gmail | **1** | In the guide's Step 4. Gmail isn't activated on `mpc.ad`, so no mailbox yet |
| Google Chat | 0 | |
| Google Meet | 0 | |
| Google Play Console | 0 | |
| Google Vault | 0 | |
| Groups for Business | 0 | |
| Keep | 0 | |
| Sites | 0 | |
| Tasks | 0 | |
| Workspace Studio | 0 | |
Not in the list: SAML apps (none configured), Google Cloud console (separate "Google Cloud session control").

## WARNING found while taking this list
Admin Console, Drive and Docs, and Gmail each show **1 active applied at MPC** (the top-level OU, which includes the super admin).
The access level needs a Fleet-managed iOS device, so the admin's Mac can't satisfy it. Risk: the admin can be locked out of the Admin
console, Drive and Gmail. The assignment should be on the OU **Fleet iOS test** only, and never on Admin Console.
