Thanks for the details! Yes, and in Fleet it's simpler than the Jamf setup: users help themselves, and nobody has to remember to flush anything. I'm testing it in our lab now and will confirm once it works end to end.

*How it works*
• *The user runs it when they need it:* Fleet Desktop > Self-service > "Admin rights for 20 minutes". It's your MakeMeAdmin idea: the script makes them an admin and a LaunchDaemon makes them standard again after 20 minutes.
• *Once per Mac per 24 hours:* each run leaves a timestamp on the Mac. The script refuses a second run within 24 hours and tells the user when they can use it again. A dynamic label on that timestamp hides the item from self-service in the meantime, and it comes back on its own after 24 hours.
• *IT support handles exceptions:* if someone needs a second grant the same day, IT support runs a small reset script from the Mac's page in Fleet. That's your flush. IT support can also run the grant for the user, for example on a call.

*Why it fits IT support and GitOps*
• Everything is in your GitOps repo: two scripts, one dynamic label, one self-service item. Nothing has to be added to or removed from a group by hand.
• The *Technician* role can run saved scripts but can't edit them, and GitOps mode doesn't block running scripts.
• Every run is in Fleet's activity log: which Mac, when, and whether the user or IT support ran it.
• The demotion still happens after sleep or a restart, and the script never demotes someone who was already an admin.

Your engineers keep SAP Privileges as they have it today. If you'd like a different window than 24 hours, it's one number in the script and one in the label.
