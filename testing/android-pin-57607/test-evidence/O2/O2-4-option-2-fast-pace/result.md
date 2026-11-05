# O2-4: option 2 fast pace

- **Started:** 2026-11-05T11:23:36Z
- **Objective:** Can a fast pace block setup? Does the new unblock message read well?
- **Expected:** PASS or PARTIAL; FAIL if stuck in setup

## Steps and evidence

- **Fleet:** https://fleet.mpc.ad (4.94.0)

- **Pace:** fast. **Fleet profiles:** pin-block-0 and pin-unblock-message, new wording ("Open your notifications and tap \"Unblock your apps\", or set a PIN in Settings."), merged 11:22:49, served by 11:23:24.
- **Capture:** iPhone camera 1 frame/s (private/cam/O2-4/). Mac clock: +0.023433 s.
- Before scan: phone wiped with fleetctl mdm wipe at 11:22:09 (Fleet showed wiped 11:22:17), host 33 deleted, serial lookup 404: new host.

- 11:26:01 user: started (QR scanned)

- 11:29:01 user: done

- Server: 11:28:00.871 PubSub ENROLLMENT, host 34. Watch: 11:28:19 both profiles pending; 11:28:41 pin-block-0 failed USER_ACTION, pin-unblock-message verified. 11:28:21.776 applied_policy_version=12, non_compliance_count=1.
- 11:29:08 camera: home screen, Google, Messages, Camera and search greyed out; Phone and Play Store in colour. User: no PIN prompt in setup, apps greyed out.

- 11:29:41 camera: Device Policy screen "Set a new screen lock. If a new screen lock isn't set, this device will be erased. 29 days left", "Set a screen lock: Choose a PIN, pattern or password", button "Set screen lock" (the 30-day wipeAction shown to the end user).

- 11:29:11-11:29:15 camera: first swipe down showed Samsung's one-time tip "Notifications / Quick settings: Swipe down from the top right corner of the screen to open the quick settings panel. Swipe down from anywhere else on the top of the screen to open the notification panel." OK. Behind it: "Unblock your apps" (Set a new screen lock).
- 11:29:23-11:29:29 camera: tap on a blocked app: **"Action not allowed" with the new text: "Your apps are blocked until you set a screen lock PIN. Open your notifications and tap "Unblock your apps", or set a PIN in Settings."** Close.
- `03-activity.txt`: `'tools/fleet-activity.sh' '<redacted>' '2026-11-05T11:23:36Z'`
- `04-server-logs.txt`: `'tools/server-logs.sh' '2026-11-05T11:23:36Z'`
- `05-home-apps-greyed.jpg` (camera frame, 11:29:08 UTC)
- `06-samsung-notifications-tip.jpg` (camera frame, 11:29:13 UTC)
- `07-action-not-allowed-new-message.jpg` (camera frame, 11:29:25 UTC)
- `08-set-a-new-screen-lock-erase-warning.jpg` (camera frame, 11:29:41 UTC)
- `09-home-unblocked.jpg` (camera frame, 11:30:12 UTC)

- 11:30:00 "Choose screen lock" (PIN), 11:30:03-11:30:09 Set PIN, confirm, OK; 11:30:12 home, apps in colour.
- Fleet: both profiles verified by 11:30:50. 11:30:24 fleet_enrolled activity (Fleet app).
- **Result:** no PIN prompt in setup (policy on the phone 21 s after enrollment). Apps blocked at home. The reworded unblock message showed in the block dialog; the user followed it (notifications, "Unblock your apps") and set a PIN in about 1 minute.

## Result: PARTIAL

No PIN prompt in setup; apps blocked at home; the reworded unblock message showed and led to the PIN in about 1 minute.

_Finished 2026-11-05T11:31:31Z_
