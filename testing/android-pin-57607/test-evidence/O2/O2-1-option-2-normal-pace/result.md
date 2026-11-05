# O2-1: option 2 normal pace

- **Started:** 2026-11-05T09:18:06Z
- **Objective:** PIN prompt in setup
- **Expected:** PIN prompt, no block

## Steps and evidence

- **Fleet:** https://fleet.mpc.ad (4.94.0)

- **Capture:** no video. Device screens and times are manual notes; the Fleet side is the watch timeline.

- 09:18:12 before scan: serial lookup HTTP 404 (new host)

- 09:30:35 before scan: Render redeploy started to set FLEET_LOGGING_DEBUG=true (same 4.94.0 image). Watch lines during the redeploy may show API errors.

- 09:34:25 before scan: redeploy done, Fleet healthy, debug log lines present.

- 09:37:16 first watcher stopped before the scan (it would have ended mid-setup); 02-watch.txt is the run's timeline.

- 09:39:20 camera: "Getting your phone ready... This may take a few minutes" (frame private/cam/O2-1/20261105T093920Z.jpg)

- Camera timeline (1 frame/s in private/cam/O2-1/, read after the fact):
  - 09:36:00-09:37:04 factory reset, screen dark
  - 09:37:12 "Scanning for a QR code" (T0 is the scan, between 09:37:12 and 09:37:36)
  - 09:37:36-09:38:56 "Connect to Wi-Fi", password entered (screen dark about 09:38:16-09:38:32)
  - 09:39:04-09:40:00 "Getting your phone ready... This may take a few minutes"
  - 09:40:08-09:40:16 "For your review" (Samsung EULA, diagnostic data, agree to all), Next
  - 09:40:22 "Service provider setup: Your phone needs to restart to set up features and services from your service provider" with a Restart button (Samsung carrier step, not a Fleet or policy screen)
  - 09:40:32-09:40:48 restart, "Samsung Galaxy" boot screen
  - Host not in Fleet at 09:40:42 (lookup 404).
- `04-activity.txt`: `'tools/fleet-activity.sh' '<redacted>' '2026-11-05T09:18:06Z'`
- `05-server-logs.txt`: `'tools/server-logs.sh' '2026-11-05T09:18:06Z'`
- `06-qr-scanner.jpg` (camera frame, Mac 09:37:12, server time 09:37:24)
- `07-service-provider-restart.jpg` (camera frame, Mac 09:40:22, server time 09:40:34)
- `08-registering-device.jpg` (camera frame, Mac 09:42:25, server time 09:42:37)
- `09-set-a-new-screen-lock.jpg` (camera frame, Mac 09:42:53, server time 09:43:05)
- `10-home-screen.jpg` (camera frame, Mac 09:43:45, server time 09:43:57)

- **Clock:** the Mac was 12.07 s behind (sntp against time.apple.com, and Fleet's Date header). Watch lines, camera file names and note times are Mac time. Times below are corrected to server time (Mac + 12 s).
- Camera, continued (server time):
  - 09:41:01-09:41:29 boot ("Samsung Galaxy", "Powered by Android")
  - 09:41:41-09:41:57 "Downloading..."
  - 09:42:01-09:42:05 "Set up your phone" (Device Policy), Continue
  - 09:42:09 "Getting ready for work setup..."
  - 09:42:13 "This Galaxy A27 5G isn't private", Accept and continue
  - 09:42:17-09:43:01 "Registering device..."
  - 09:43:05 **"Set a new screen lock"**, Set screen lock. Then "Protect your phone" (PIN, Password, Pattern), PIN
  - 09:43:17-09:43:37 Set PIN, confirm, OK
  - 09:43:41 "Your work checklist" (Install work apps), then "Registering device...", "Checking for updates...", Google terms, Accept
  - 09:43:57 home screen, notice: "Based on the admin policy set for your phone, the following agreement has been withdrawn: Sending of Diagnostic Data"
- Server log (server time, 05-server-logs.txt):
  - 09:42:53.151 PubSub ENROLLMENT received, host created (created_at 09:42:53)
  - 09:42:57.405 android profile reconciler processed 1 host, 1 profile (per-host policy assigned 4 s after enrollment)
  - 09:43:05.275 STATUS_REPORT: applied_policy_version=2, non_compliance_count=1 (same second as "Set a new screen lock" on the device)
  - 09:43:42.686 non_compliance_count=1 after policy version 3; profile Verified in Fleet at 09:43:43
- Watch (corrected): host in Fleet 09:42:55, pin-block-0 pending 09:43:00, failed USER_ACTION 09:43:05, verified 09:43:43.
- **Policy arrived on:** "Registering device...", before the screen lock step. Android Device Policy then asked for a screen lock as its own setup step.
- **PIN prompt in setup:** yes, "Set a new screen lock" at 09:43:05. **Blocked by your work policy:** no. **Home screen:** 09:43:57 with a PIN set. Apps not tested blocked: the PIN was set before the home screen.
- **Activity log:** one global activity, fleet_enrolled at 09:44:13 (80 s after enrollment). NOTES.md says Android has no enrollment activity; this needs a code check before relying on it.
- Device: Samsung SM-A276B, Android 16, security patch 2026-05-05 (Fleet os_version). New host (serial not in Fleet before the run). Samsung's own "Service provider setup" restart came before enrollment.

## Result: PASS

PIN prompt in setup ("Set a new screen lock") 12 s after enrollment, no block, home screen with PIN set; profile Verified.

_Finished 2026-11-05T09:46:41Z_
