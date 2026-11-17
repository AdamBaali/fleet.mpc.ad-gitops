Thanks for the details! Fleet can do this with SAP Privileges, the tool you already use, delivered through self-service. I'm testing it in our lab now and will confirm once it works end to end.

*How it works*
IT support adds the Mac to a manual label, for example "Privileges approved". That label does two things:
• Privileges (a Fleet-maintained app, 2.6.0) appears in the user's *Fleet Desktop > Self-service*, and they install it themselves.
• The Mac gets a Privileges profile: `ExpirationInterval` = 20, `AllowPrivilegeRenewal` = false, `ReasonRequired` = true, `RevokePrivilegesAtLogin` = true. So they get 20 minutes of admin, give a reason, and can't extend it.
Macs outside the label get a locked profile instead (`EnforcePrivileges` = `user`). That matters because Fleet doesn't uninstall an app when a Mac leaves the label: Privileges stays installed but can't grant admin until IT support approves the Mac again. Removing a Mac from the label also ends a grant that's still running.
A third profile, on every Mac, approves Privileges' background items and its notifications, based on SAP's `Example_ApprovePrivileges`. The profiles use the same format as SAP's Privileges MDM Configurator, so you can build your own there. Your engineers keep their own Privileges profile in their fleet.

*Approving and clearing, with GitOps*
• Define the label in your YAML with `hosts: []`. Every GitOps run empties it, so your 6am run clears all approvals each morning, like your flush.
• During the day, IT support adds a Mac through the API: `POST /api/v1/fleet/hosts/:id/labels` with `{"labels": ["Privileges approved"]}`. They remove it with `DELETE` on the same path. The UI works too when GitOps mode is off. GitOps mode only restricts the UI, not the API.
• One catch: *any* GitOps run clears the label, not only the 6am one, so a merge during the day ends approvals early. If that's a problem, leave `hosts` out of the YAML and clear the label at 6am with one API call: `PATCH /api/v1/fleet/labels/:id` with `{"host_ids": []}`.

*Audit*
Fleet's activity log shows who added each Mac to the label. Privileges logs the user's reason, and its `RemoteLogging` key can send each grant to your log platform by syslog or webhook.
