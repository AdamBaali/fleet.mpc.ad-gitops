# O2-3: option 2 fast pace

- **Started:** 2026-11-05T11:05:44Z
- **Objective:** Can a fast pace block setup? Does the unblock message show?
- **Expected:** PASS or PARTIAL; FAIL if stuck in setup

## Steps and evidence

- **Fleet:** https://fleet.mpc.ad (4.94.0)

- **Pace:** fast. **Fleet profiles:** pin-block-0 and pin-unblock-message (PR merged 11:04:40, applied by 11:05:19).
- **Capture:** iPhone camera 1 frame/s (private/cam/O2-3/). Mac clock: +0.074125 s.
- 11:05:46 before scan: phone wiped with fleetctl mdm wipe (Fleet showed wiped 10:56:19), host 32 deleted, serial lookup 404: new host.

- 11:13:34 server: enrollment page opened (fleet 14, fully managed). 11:13:50 ready to scan.

- 11:14:56 user: "it's working away"

- 11:15:37 user: "registering now"

- 11:18:57 user: no PIN prompt in setup; the custom message showed.
- `03-activity.txt`: `'tools/fleet-activity.sh' '<redacted>' '2026-11-05T11:05:44Z'`
- `04-server-logs.txt`: `'tools/server-logs.sh' '2026-11-05T11:05:44Z'`
- `05-registering-device.jpg` (camera frame, 11:15:38 UTC)
- `06-google-services-policy-arrives.jpg` (camera frame, 11:16:30 UTC)
- `07-action-not-allowed-custom-message.jpg` (camera frame, 11:17:50 UTC)
- `08-set-a-new-screen-lock.jpg` (camera frame, 11:18:04 UTC)
- `09-home-unblocked.jpg` (camera frame, 11:18:16 UTC)

- Timeline (camera and server, both on time):
  - 11:15:30 "Set up your phone" (Device Policy), 11:15:34 "This Galaxy A27 5G isn't private"
  - 11:15:38-11:16:14 "Registering device..."
  - 11:16:00.176 server: PubSub ENROLLMENT, host 33 created
  - 11:16:16 watch: both profiles pending (profile job ran about 16 s after enrollment)
  - 11:16:18 "Checking for updates..."; 11:16:22-11:16:38 "Google services"
  - 11:16:21.196 server: applied_policy_version=8, non_compliance_count=1 (policy on the phone after registering ended)
  - 11:16:39 watch: pin-block-0 failed USER_ACTION, pin-unblock-message verified
  - 11:16:42-11:17:26 screen dimmed and off (no input for about 45 s: pace was not fast on this screen)
  - 11:17:34-11:17:38 "For your review", Next; 11:17:44 home screen, apps greyed out
  - 11:17:48-11:17:56 tap on an app: **"Action not allowed" with the custom text: "Your apps are blocked until you set a screen lock PIN. Swipe down from the top of the screen and tap "Unblock your apps" to set one."** and Close. Samsung keeps its own title.
  - 11:18:04 "Set a new screen lock", 11:18:08-11:18:12 Set PIN; 11:18:13 watch: pin-block-0 verified; 11:18:16 home, apps unblocked
  - 11:18:51 fleet_enrolled activity (Fleet app's orbit enrollment)
- **shortSupportMessage:** shown in the blocked-app dialog on this Samsung (One UI, Android 16). Not tested on other makes.

## Result: PARTIAL

No PIN prompt in setup (policy on the phone 21 s after enrollment, after registering). Apps blocked at home; the custom unblock message showed in the block dialog; PIN set from the notification.

_Finished 2026-11-05T11:20:03Z_
