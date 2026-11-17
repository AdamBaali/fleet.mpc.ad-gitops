Yes, Fleet can do this, and we have two ways. I'm testing both in our lab now and will confirm once each is proven end to end.

*Option 1: SAP Privileges, the tool you already use (my pick).*
Install Privileges on the non-Engineering Macs too (it's a Fleet-maintained app). Each Mac gets one of two profiles, chosen by a manual label such as "Privileges approved":
• *Not in the label:* `EnforcePrivileges` = `user`. The app is there but can't grant admin.
• *In the label:* `ExpirationInterval` = 20, no renewal, reason required, revoked at login.
IT support adds the Mac to the label, and the user clicks Privileges when they need it. Remove the Mac from the label and the locked profile comes back. That also ends a grant that's still running. Your engineers keep their own Privileges profile in their fleet.

*Option 2: a script, closest to your current policy.*
Same idea as your MakeMeAdmin script. It promotes the user and a LaunchDaemon demotes them after 20 minutes. It checks a stored expiry every minute, so sleep and restarts don't skip the demotion, and it never demotes someone who was already an admin. IT support either runs it from the host page as a saved script, or the user runs it from Fleet Desktop when their Mac is in a label. There's no "flush" step: just run it again.

*How IT support approves and clears, with GitOps:*
• Define the label in your GitOps YAML with `hosts: []`. Every GitOps run then empties it, so your 6am run clears all approvals each morning, like your flush.
• During the day, IT support adds a Mac with the API: `POST /api/v1/fleet/hosts/:id/labels` with `{"labels": ["Privileges approved"]}`, and removes it with `DELETE` on the same path. The UI works too when GitOps mode is off. GitOps mode only restricts the UI, not the API.
• One thing to know: any GitOps run clears the label, not only the 6am one. A merge during the day ends that day's approvals early. If that's a problem, leave `hosts` out of the YAML (Fleet then keeps the membership) and clear the label at 6am with one API call instead: `PATCH /api/v1/fleet/labels/:id` with `{"host_ids": []}`.

The *Technician* role can add Macs to labels and run saved scripts, but can't edit scripts or run its own. Every change is in the activity log.
