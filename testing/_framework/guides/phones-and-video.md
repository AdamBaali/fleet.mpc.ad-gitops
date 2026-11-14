# Phones and video

Record the phone's screen with a UTC clock in the picture, and watch it live while it records, so the video lines up with
Fleet's activity log and the watch timeline.

## Record
```bash
cd testing/<project>
../_framework/tools/phone-cam.sh list               # camera names
../_framework/tools/phone-cam.sh record O2-1        # records, with a live view window. Ctrl-C stops
../_framework/tools/phone-cam.sh frames O2-1 "" 1   # or one still a second, named by UTC time
../_framework/tools/phone-cam.sh still <video> 01:23 out.png
```
- The iPhone is the camera, pointed at the phone under test. It shares the Mac's Apple Account, Wi-Fi, and Bluetooth, and stays locked and nearby.
- The live view comes through a pipe from the same recording, so the camera is open once. Closing the view window doesn't stop the recording.
- The Mac is muted for the run and restored after, to keep the Continuity Camera chime out of the video. Also silence the iPhone.
- Files go to `private/video/<ID>/` (git ignores it). The camera sees the room: choose, crop, and mask stills with `maskbox` before they go in `test-evidence/`.
- Run `bin/clock-check.sh` first. Note T0 (for example the QR scan) and give later times as T+mm:ss.
- Tested on Linux with a test pattern (`PHONE_CAM_TEST=1`): clock, file, live view pipe, and viewer-closed case. Run `list` once on a new Mac before a real run.

## iPhone under test
Mirror it with iPhone Mirroring and capture the window only: `testing/google-ca-55107/scripts/live-shots.sh <dir> [minutes]` (a frame every 4 s, skipping repeats).

## Android
adb can't capture a setup wizard (USB debugging is off after a reset), and screenshots can't be copied off a company-owned phone. Use the camera.
Run loop (`testing/android-pin-57607/TEST-PLAN.md`): wipe with `fleetctl mdm wipe` and delete the host, open the fleet's company-owned enrollment link in a laptop browser (the QR token lasts 1 hour and works once), start `watch-host.sh <serial>` and `phone-cam.sh record <ID>`, tap the welcome screen 6 times, scan (T0), note each screen. Scripts: `testing/android-pin-57607/tools/` (`run.sh`, `guide.sh`, `watch-host.sh`, `fleet-activity.sh`, `server-logs.sh`). Remove manual labels between runs.
