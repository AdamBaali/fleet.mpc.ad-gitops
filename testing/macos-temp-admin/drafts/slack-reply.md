Hey! Here's how I'd set up your "Temp 20 mins admin" in Fleet for non-Engineering. It works like your Jamf policy (once per computer, IT support flushes it) but uses only Fleet: no extra app and no static group to manage.

*How it works*
1. *The user runs it when they need it:* Fleet Desktop > Self-service > "Admin rights for 20 minutes". The script adds them to `admin` and loads a LaunchDaemon that makes them standard again after 20 minutes. It still demotes after sleep or a restart, and it never demotes someone who was already an admin.
2. *Once per Mac:* the grant leaves a marker file on the Mac. While it's there, the script refuses to run again and tells the user to ask IT support.
3. *The button disappears:* a dynamic label on the marker ("Temp admin used") hides the item from Self-service. The script asks Fleet to refetch the Mac right away, so the button disappears within minutes.
4. *IT support flushes it:* when the user needs admin again, IT support runs the reset script from the Mac's page in Fleet. It deletes the marker, and the button is back within minutes. IT support can also run the grant for the user, for example on a call.

*Why it fits IT support and GitOps*
• It's two scripts, one dynamic label and one self-service item, all in your GitOps repo.
• The *Technician* role can run saved scripts but can't edit them or run its own, and GitOps mode doesn't block running scripts.
• Every grant and reset is in Fleet's activity log: which Mac, when, and who ran it.

*Assets*
• Grant script: https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/lib/macos/scripts/temp-admin.sh
• Reset script for IT support: https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/lib/macos/scripts/temp-admin-reset.sh
• Example fleet YAML (label, self-service item, saved scripts): https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/fleets/temp-admin-lab.yml
Copy the `labels`, `controls.scripts` and `software.packages` parts into your non-Engineering fleet file.

*Why not Privileges for this?* Your engineers keep it as is. For "once until IT resets", Privileges 2.6.0 has no setting. SAP documents a daily admin budget, but it's for 2.7.0, which isn't out yet, and it resets every day rather than waiting for IT.

I'm finishing the end-to-end test on a Mac in our lab and will confirm here once it's done. Happy to jump on a call to walk through it.
