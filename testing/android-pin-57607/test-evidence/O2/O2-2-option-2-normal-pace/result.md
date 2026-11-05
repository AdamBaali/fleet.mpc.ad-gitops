# O2-2: option 2 normal pace

- **Started:** 2026-11-05T10:11:54Z
- **Objective:** PIN prompt in setup
- **Expected:** PIN prompt, no block

## Steps and evidence

- **Fleet:** https://fleet.mpc.ad (4.94.0)

- **Capture:** iPhone camera, 1 frame/s (private/cam/O2-2/). Mac clock checked: +0.041962 s from time.apple.com.
- 10:11:55 before reset: host 31 (O2-1) deleted from Fleet, serial lookup 404, so this is a new host.

- 10:37:52 user: connected to Wi-Fi

- 10:38:58 user: "policy is now showing" (frame private/cam/O2-2/20261105T103857Z.jpg)

  - 10:38:57 camera: "Set up your phone" (Device Policy notice, Continue). Host not in Fleet yet (404 at 10:38:58).

- 10:39:26 user: "registering now"

- 10:42:16 user: "it went through, no pin"

- Camera (1 frame/s, Mac clock correct):
  - 10:39:20-10:39:52 "Registering device..." (host created 10:39:43)
  - 10:39:56 "Checking for updates..."
  - 10:40:00-10:40:20 "Google services"
  - 10:40:24-10:41:44 screen dimmed then off (no input for about 80 s)
  - 10:41:52 Google terms, Accept; 10:41:56 "For your review", Next
  - 10:42:00 home screen. **No "Set a new screen lock" screen at any point. No block screen.**
- 10:42:16 Fleet: pin-block-0 failed, USER_ACTION (phone reports no compliant PIN).

- Server log (server time):
  - 10:39:43.214 PubSub ENROLLMENT, host 32 created
  - 10:39:59.266 android profile reconciler processed 1 host, 1 profile (**16 s after enrollment**; O2-1: 4 s)
  - 10:40:02.386 STATUS_REPORT: applied_policy_version=4, non_compliance_count=1 (phone on "Google services"; "Registering device..." ended 10:39:52)
  - 10:40:18.548 policy version 5, non_compliance_count=2
- **Policy arrived on:** "Google services", after Device Policy's "Registering device..." step. No screen lock step followed.

- 10:43:44 user: many apps greyed out, only Play Store opens.

- 10:43:43 camera: home screen with Google, Messages, Camera and the search widget greyed out; Phone and Play Store in colour. Apps blocked after setup, with no PIN prompt before it.

- 10:44:14 camera: tapping a greyed app shows "Action not allowed. You do not have permission to perform this action. Contact your organisation's IT administrator for more information." with Close. Nothing on that dialog leads to setting a PIN.

- 10:44:53 user: notification shade shows "Unblock your apps: set a new screen lock" (exact wording to confirm from the camera frame).

- 10:44:53 camera: notification shade. Top notification from Device Policy: "Unblock your apps" / "Set a new screen lock" (text small in the frame; matches what the user read). Also "Privacy reminder" (11:39 phone time, UTC+1). The notification was posted, but setup never showed it as a screen.

- 10:45:58 user: PIN set.

- 10:46:13 user: apps unblocked. Fleet showed pin-block-0 verified at 10:45:58 (first poll after the PIN).
- `03-activity.txt`: `'tools/fleet-activity.sh' '<redacted>' '2026-11-05T10:11:54Z'`
- `04-server-logs.txt`: `'tools/server-logs.sh' '2026-11-05T10:11:54Z'`
- `05-set-up-your-phone.jpg` (camera frame, 10:38:57 UTC)
- `06-registering-device.jpg` (camera frame, 10:39:40 UTC)
- `07-google-services-policy-arrives.jpg` (camera frame, 10:40:08 UTC)
- `08-home-apps-greyed.jpg` (camera frame, 10:43:43 UTC)
- `09-action-not-allowed.jpg` (camera frame, 10:44:14 UTC)
- `10-unblock-your-apps-notification.jpg` (camera frame, 10:44:53 UTC)
- `11-set-a-new-screen-lock.jpg` (camera frame, 10:45:36 UTC)
- `12-home-unblocked.jpg` (camera frame, 10:45:51 UTC)

- After the notification (camera, server time):
  - 10:45:36 "Set a new screen lock" (opened from the notification), 10:45:39-10:45:48 Set PIN, confirm, OK
  - 10:45:49.265 server: non_compliance_count=0. Watch: pin-block-0 verified 10:45:53
  - 10:45:51 home screen with all apps in colour; 10:46:06 Google opens
- Activity: fleet_enrolled at 10:43:17 (Fleet app's orbit enrollment, 3:34 after MDM enrollment).
- **Result:** no PIN prompt in setup. Home screen at 10:42:00 with apps blocked ("Action not allowed") and only a Device Policy notification ("Unblock your apps") to recover. Apps blocked from about 10:42:00 to 10:45:51 (4 min, user knew to look in notifications).

## Result: FAIL

No PIN prompt in setup: Fleet's profile job ran 16 s after enrollment and the policy reached the phone after Device Policy's registering step. Home screen with apps blocked until the user found the "Unblock your apps" notification.

_Finished 2026-11-05T10:46:56Z_
