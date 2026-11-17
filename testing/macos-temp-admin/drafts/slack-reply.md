Hey! Here are two ways to do your "Temp 20 mins admin" in Fleet for non-Engineering. Both follow your Jamf flow: IT support approves a Mac when someone needs admin, the user gets 20 minutes once, and there's no flush step. The next approval is the next grant.

*Option 1: Fleet only (no extra app)*
1. IT support opens the Mac in Fleet and runs the "Approve temp admin" script. That's your "add to the static group".
2. "Admin rights for 20 minutes" appears in Fleet Desktop > Self-service, driven by a dynamic label on the approval.
3. The user runs it once when they're ready. A LaunchDaemon makes them standard again after 20 minutes, even after sleep or a restart.
4. The grant uses up the approval and the button disappears within minutes.
Assets:
• Approve script: https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/lib/macos/scripts/temp-admin-approve.sh
• Grant script (the self-service item): https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/lib/macos/scripts/temp-admin.sh
• Fleet YAML: https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/fleets/temp-admin-lab.yml

*Option 2: SAP Privileges, the tool your engineers already use*
1. Every non-Engineering Mac gets Privileges (a Fleet-maintained app) with one profile: `LimitToGroup` set to a local group, 20 minutes, no renewal, reason required, revoked at login. Until IT support approves, Privileges is locked.
2. IT support runs the "Approve Privileges" script from the Mac's page. It adds the user to that local group.
3. The user opens Privileges, enters a reason, and gets 20 minutes.
4. When the grant ends, a small watcher takes the user out of the group, so the approval is used once.
Assets:
• Approve script: https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/lib/macos/scripts/privileges-approve.sh
• Privileges profile: https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/lib/macos/configuration-profiles/privileges-temp-admin.mobileconfig
• Fleet YAML: https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/fleets/privileges-lab.yml
Privileges 2.6.0 has no built-in "once per approval", which is why the watcher is there. SAP documents a daily admin budget for 2.7.0, but it isn't released yet.

*Which to pick*
• *Option 1* has fewer parts and no third-party app.
• *Option 2* gives users the Privileges app they may know from Engineering, makes them type a reason, and can send every grant to your log platform with Privileges' `RemoteLogging`.

*In both options*
• IT support approves from the Mac's page in Fleet. The *Technician* role can run saved scripts but can't edit them or run its own, and GitOps mode doesn't block running scripts.
• Every approval is in Fleet's activity log: which Mac, when, and who approved it.
• Neither ever demotes someone who was already an admin.

I'm finishing end-to-end tests of both on a Mac in our lab and will confirm here once they're done. Happy to jump on a call to walk through them.
