Yes, Fleet can do this, and we have two ways. I'm testing both in our lab now and will confirm once each is proven end to end.

*Option 1: SAP Privileges, the tool you already use (my pick).*
Install Privileges on the non-Engineering Macs too (it's a Fleet-maintained app). Each Mac gets one of two profiles, chosen by a manual label such as "Privileges approved":
• *Not in the label:* `EnforcePrivileges` = `user`. The app is there but can't grant admin.
• *In the label:* `ExpirationInterval` = 20, no renewal, reason required, revoked at login.
IT support adds the Mac to the label, and the user clicks Privileges when they need it. Remove the Mac from the label and the locked profile comes back. That also ends a grant that's still running. Your engineers keep their own Privileges profile in their fleet.

*Option 2: a script, closest to your current policy.*
Same idea as your MakeMeAdmin script. It promotes the user and a LaunchDaemon demotes them after 20 minutes. It checks a stored expiry every minute, so sleep and restarts don't skip the demotion, and it never demotes someone who was already an admin. IT support either runs it from the host page as a saved script, or the user runs it from Fleet Desktop when their Mac is in a label. There's no "flush" step: just run it again.

*For IT support in both options:* the *Technician* role can add Macs to the label and run saved scripts, but can't edit scripts or run their own. Every change is in the activity log.

Quick question: do you run Fleet with GitOps mode on? If so, I want to confirm a Technician can still add Macs to that label from the UI.
