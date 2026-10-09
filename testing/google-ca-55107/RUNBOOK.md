# Runbook: the iPhone test (do in this order)
The tester enrolls the iPhone and signs in; the commands capture the evidence. Test IDs are from `TEST_PLAN.md`.

## 0. Before the phone (the tester, 5 minutes)
1. `tools/setup-ios-secret.sh`, then push the GitOps repo with GitHub Desktop (creates the **iOS Google Lab** fleet and the new `google-sync` workflow, manual only).
2. Rotate the admin Fleet token that was pasted in chat.
3. In Admin console > Security > Context-Aware Access > Assign access levels, check that **Admin Console, Drive and Gmail** show 0 active at **MPC** and 1 at **Fleet iOS test**.
4. Mirroring: iPhone Control Center > **Screen Mirroring** > this Mac (AirPlay Receiver is on). Both on the same network (192.168.4.x).
5. Turn on Do Not Disturb and hide notification previews on the phone.

## 1. Enroll in Fleet (G-5)
- Enroll the iPhone in the fleet **iOS Google Lab** (ABM or manual, per the Fleet guide). End user email = `managed-test@mpc.ad` (IdP end user auth, or a custom mapping through the API).
- Claude: `GET /hosts?device_mapping=true` shows the host with that email. Evidence: Fleet host page (masked) + the API output.

## 2. Create the Google device (G-6)
- On the phone sign in to the **Drive** app with `managed-test@mpc.ad` (first sign-in asks to set a new password: the tester types it).
- Expected before the sync: the access level blocks Drive (the Google client state doesn't exist yet). That is test C-2 for the managed user before sync: capture the block message and the live feed.
- Claude: `devices.list` shows 1 iOS device, `deviceUsers.list` shows the user.

## 3. Partner ID check (E-14), first
- `python3 tools/clientstate_test.py` writes `managed` under both forms (no leading C, and with the C) and reads them back. Expected from Google's docs: only **no-C** works.
- If the with-C form fails: the draft guide, the script and the access level need the no-C form. Claude fixes the access level condition (**Fleet managed iOS**) to `device.vendors["<id-without-C>-fleet"].is_managed_device == true` in the console (needs the tester's click if the classifier blocks).
- Also test the CEL key forms in monitor mode if the first form doesn't match: `<id>-fleet`, `key-<id>` (Google's access level spec shows `key-<customer id>`).

## 4. Sync, then sign in (C-1)
- `tools/run-live.sh`: token, DRY_RUN, LIVE, read back. Expected: "<device> (managed-test@mpc.ad/iphone): none -> MANAGED".
- Phone: sign in to Drive again. Expected: succeeds (C-1). Capture live feed, window PNGs, the Context Aware Access log event (Reporting > Audit and investigation, entries can take up to an hour).
- `unmanaged-test@mpc.ad` on the same phone (no Fleet email for it): Expected: **blocked** (C-2). Capture the exact message.

## 5. Edge tests, quickest first
E-2 (remove host from Fleet, run sync, blocked), E-3 (unenroll MDM), E-13 (empty Fleet list guard, already proven on a mock), E-11 (run twice, no duplicate writes), then G-12 (turn on the schedule for a few hours).

## 6. Finish
Build `EVIDENCE.md`, write `GUIDE-FINDINGS.md` edits as a diff (`proposed/guide-script-edits.diff` is the start), draft the issue update. Never post.
Teardown list: cancel/downgrade the Google subscription (flexible plan), delete the Cloud project, delete the service account key and delegation entry, remove the API-only Fleet user and fleet, delete the test users, remove the lab workflow secrets.
