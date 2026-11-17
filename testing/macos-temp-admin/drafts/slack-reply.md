Thanks for the details! Yes, and in Fleet it's simpler than the Jamf setup: one saved script, no group, no flush. I'm testing it in our lab now and will confirm once it works end to end.

*How it works*
• Add the script to your GitOps repo under `controls.scripts` for the non-Engineering fleet. It's your MakeMeAdmin idea: it adds the signed-in user to `admin` and loads a LaunchDaemon that removes them after 20 minutes.
• When someone needs admin, IT support opens their Mac in Fleet and clicks *Run* on that script. The user is an admin right away, for 20 minutes.
• To grant it again, IT support clicks *Run* again. Each run is one grant, so there's no static group to manage and no flush.

*Why it's safe for IT support to own*
• The *Technician* role can run saved scripts but can't edit them or run its own, so IT support gets exactly this button and nothing more.
• GitOps mode doesn't block running scripts, so it works with your GitOps setup.
• Every run is in Fleet's activity log with who ran it, on which Mac, and when. The script's output shows when the rights expire.
• It stores the expiry time and checks it every minute, so the demotion still happens after the Mac sleeps or restarts. It never demotes someone who was already an admin.

Your engineers keep SAP Privileges as they have it today. I'll share the script once testing is done.
