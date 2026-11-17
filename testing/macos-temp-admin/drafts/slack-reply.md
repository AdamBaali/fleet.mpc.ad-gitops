Thanks for the details! Yes, and in Fleet it's simpler than the Jamf setup: one script, no static group, no flush. I'm testing it in our lab now and will confirm once it works end to end.

*How it works*
• It's your MakeMeAdmin idea: the script adds the signed-in user to `admin` and loads a LaunchDaemon that removes them after 20 minutes.
• Add it once in your GitOps repo for the non-Engineering fleet, as a self-service item ("Admin rights for 20 minutes") and as a saved script. Both point to the same file.
• *The user runs it when they need it:* Fleet Desktop > Self-service > *Run*. Afterwards the button says *Rerun*, so they can take another 20 minutes later without IT support resetting anything.
• *IT support can run it for them* from the Mac's page in Fleet, for example during a support call. The *Technician* role can run saved scripts but can't edit them, and GitOps mode doesn't block running scripts.

*Visibility and safety*
• Every run is in Fleet's activity log: which Mac, when, and whether the user or IT support ran it. The output shows when the rights expire.
• It stores the expiry time and checks it every minute, so the demotion still happens after sleep or a restart. It never demotes someone who was already an admin.
• The trade-off: anyone on that fleet can take 20 minutes whenever they like. If some people shouldn't, you can hide the item from them with a label.

Your engineers keep SAP Privileges as they have it today.
