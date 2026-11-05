# O2-3: option 2 fast pace

- **Started:** 2026-11-05T11:05:44Z
- **Objective:** Can a fast pace block setup? Does the unblock message show?
- **Expected:** PASS or PARTIAL; FAIL if stuck in setup

## Steps and evidence

- **Fleet:** https://fleet.mpc.ad (4.94.0)

- **Pace:** fast. **Fleet profiles:** pin-block-0 and pin-unblock-message (PR merged 11:04:40, applied by 11:05:19).
- **Capture:** iPhone camera 1 frame/s (private/cam/O2-3/). Mac clock: +0.074125 s.
- 11:05:46 before scan: phone wiped with fleetctl mdm wipe (Fleet showed wiped 10:56:19), host 32 deleted, serial lookup 404: new host.

- 11:09:15 user: "Getting your phone ready"

- 11:10:28 user: "got a strange error"

- Attempt 1 (camera, server time):
  - 11:08:19 server: company-owned enrollment token created (enrollment page opened)
  - 11:08:38-11:08:41 QR scan; 11:08:50-11:09:11 Connect to Wi-Fi
  - 11:09:14-11:10:05 "Getting your phone ready..."; 11:10:08-11:10:11 "Downloading..."; 11:10:15-11:10:24 "Getting ready for work setup..."
  - 11:10:27 **"Can't set up device. If you have any questions, contact your IT admin"** with Reset
  - No PubSub ENROLLMENT reached Fleet, serial lookup 404: provisioning failed before enrollment, so no Fleet policy was involved.
  - Differences from O2-1 and O2-2: the phone was wiped through Fleet (fleetctl mdm wipe, 10:56) instead of reset by hand, and Samsung's "For your review" and "Service provider setup" restart didn't appear. Cause not known.

- 11:13:50 attempt 2: phone reset from the "Can't set up device" screen, new enrollment page loaded, ready to scan.

- 11:14:56 user: "it's working away"

- 11:15:37 user: "registering now"

- 11:18:57 user: no PIN prompt in setup; the custom message showed.
- `03-activity.txt`: `'tools/fleet-activity.sh' '<redacted>' '2026-11-05T11:05:44Z'`
- `04-server-logs.txt`: `'tools/server-logs.sh' '2026-11-05T11:05:44Z'`
- `05-cant-set-up-device-attempt-1.jpg` (camera frame, 11:10:28 UTC)
- `06-registering-device.jpg` (camera frame, 11:15:38 UTC)
- `07-google-services-policy-arrives.jpg` (camera frame, 11:16:30 UTC)
- `08-action-not-allowed-custom-message.jpg` (camera frame, 11:17:50 UTC)
- `09-set-a-new-screen-lock.jpg` (camera frame, 11:18:04 UTC)
- `10-home-unblocked.jpg` (camera frame, 11:18:16 UTC)

- Attempt 2 (camera and server, both on time):
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
