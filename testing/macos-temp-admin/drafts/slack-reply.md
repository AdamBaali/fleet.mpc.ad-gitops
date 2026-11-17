Hey! Here's how I'd set up your "Temp 20 mins admin" in Fleet for non-Engineering. It follows your Jamf flow (IT support adds the Mac when someone needs it, it runs once) but uses only Fleet: no extra app, no static group, and no flush.

*How it works*
1. *IT support approves:* they open the Mac in Fleet and run the "Approve temp admin" script. That's your "add to the static group". It leaves an approval file on the Mac.
2. *The user sees the button:* a dynamic label on that file ("Temp admin approved") makes "Admin rights for 20 minutes" appear in Fleet Desktop > Self-service. The script asks Fleet to refetch the Mac, so the button shows within minutes.
3. *The user runs it once, when they're ready:* they become an admin, and a LaunchDaemon makes them standard again after 20 minutes. It still demotes after sleep or a restart, and it never demotes someone who was already an admin.
4. *The approval is used up:* the grant deletes the approval file, so the button disappears again. There's nothing for IT support to remove or flush. Next time, they approve again.

*Why it fits IT support and GitOps*
• It's two scripts, one dynamic label and one self-service item, all in your GitOps repo.
• The *Technician* role can run saved scripts but can't edit them or run its own, and GitOps mode doesn't block running scripts.
• Every approval and every grant is in Fleet's activity log: which Mac, when, and who ran it.

*Assets*
• Approve script for IT support: https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/lib/macos/scripts/temp-admin-approve.sh
• Grant script (the self-service item): https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/lib/macos/scripts/temp-admin.sh
• Example fleet YAML (label, self-service item, saved script): https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/fleets/temp-admin-lab.yml
Copy the `labels`, `controls.scripts` and `software.packages` parts into your non-Engineering fleet file.

*Why not Privileges for this?* Your engineers keep it as is. For "once per approval", Privileges 2.6.0 has no setting. SAP documents a daily admin budget, but it's for 2.7.0, which isn't out yet, and it resets every day rather than waiting for IT support.

I'm finishing the end-to-end test on a Mac in our lab and will confirm here once it's done. Happy to jump on a call to walk through it.
