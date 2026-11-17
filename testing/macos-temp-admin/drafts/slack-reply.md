Yes, this maps well to Fleet. Here's what I'm building in our lab, and I'll confirm once it's tested end to end:

*The script:* same idea as yours. It adds the signed-in user to `admin` and loads a LaunchDaemon that removes them after 20 minutes. Two differences from a plain timer:
• It stores an expiry time and checks it every minute, so the demotion still happens after the Mac sleeps or restarts.
• It never demotes someone who was already an admin, so a permanent admin can't lose rights by mistake.

*Two ways for IT support to use it (you can pick one or both):*
1. *IT support runs it.* Add it as a saved script. Anyone with the *Technician* role can run saved scripts from the host page, but can't edit them or run their own. No "flush" step: they click Run again whenever it's needed. Every run is in the activity log with who ran it.
2. *The user runs it, IT support approves.* Add the same script as a self-service item that only shows for hosts in a manual label (for example "Temp admin approved"). IT support adds the Mac to the label, which is your static group. The user clicks it in Fleet Desktop when they need it. Remove the Mac from the label to take the option away.

Quick question: do you run Fleet with GitOps mode on? If so, I want to confirm a Technician can still add hosts to that label from the UI.
