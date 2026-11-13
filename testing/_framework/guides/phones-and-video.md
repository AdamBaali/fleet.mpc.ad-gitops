# Phones and video

How to test iPhones and Android phones, and how to record the screen with a clock in it. Sources:
`testing/android-pin-57607` (camera frames, run scripts) and `testing/google-ca-55107` (iPhone Mirroring frames).

Use the iPhone as the camera. It works for any phone and any screen, including setup wizards, where other routes fail.


## Why a camera

| Route | Works when | Fails when |
|---|---|---|
| iPhone as Mac camera (`tools/phone-cam.sh`) | Always: it films whatever is on screen, including a factory-reset Android | The room, desk, and home screen are in frame, so review before sharing |
| iPhone Mirroring (window capture) | An iPhone that is locked, near the Mac, on the same Apple Account | The phone under test can't be the camera too |
| adb (`adb exec-out screencap`) | Android with USB debugging on | After a factory reset USB debugging is off until setup ends. A fleet policy can also block USB file transfer |
| Screenshots on the phone | A phone you can plug in | Android with `DISALLOW_USB_FILE_TRANSFER` (the default on company-owned devices): they can't be copied off |


## Film a screen with a UTC clock

One iPhone is the camera, pointed at the phone under test. A second phone or the Mac doing the testing is a different
device. Requirements: the iPhone on the same Apple Account as the Mac, Wi-Fi and Bluetooth on, locked, and near the Mac.
`ffmpeg` installed (`brew install ffmpeg`), and camera access granted to the terminal app.

```bash
cd testing/<project>
../_framework/tools/phone-cam.sh list                 # camera names
../_framework/tools/phone-cam.sh preview              # aim the camera, then close the window
../_framework/tools/phone-cam.sh record O2-1          # video with the UTC clock burned in. q stops it
../_framework/tools/phone-cam.sh frames O2-1 "" 1     # or one still a second, named by UTC time
../_framework/tools/phone-cam.sh still private/video/O2-1/<file>.mp4 01:23 out.png   # a still at 1:23
```

Files go to `private/video/<ID>/`. Git ignores `private/`. Pick the stills you need, crop to the phone, and mask them with
`maskbox` before they go to `test-evidence/`. Video files stay private: they show the room and may show accounts.

`phone-cam.sh` was checked on Linux with ffmpeg's test pattern (`PHONE_CAM_TEST=1`), so the clock, file names, and stills
work. The camera route itself is the same ffmpeg avfoundation input that `testing/android-pin-57607/tools/cam-log.sh`
used on a Mac. Run `list` and `preview` once on a new Mac before a real run.

Tips:
- Run `bin/clock-check.sh` first. A Mac clock 12 seconds off shifted every time in the first Android run.
- The clock burned into the video is UTC, the same zone as `watch-host.sh` and Fleet's activity log. Say "T0" aloud or note
  it when the QR code is scanned, and use T+ times in the results.
- ffmpeg keeps the camera open. `imagesnap` reopened the camera for every frame and managed one every 16 seconds.
- Select the camera by name, not index: ffplay and ffmpeg number cameras differently.
- Keep the phone under test charged, with Wi-Fi details at hand. Frame the whole screen and avoid glare.
- A 10 minute 1080p recording at crf 23 is about 100 MB.


## iPhone Mirroring (iPhone under test)

For an iPhone that must stay in the test, mirror it to the Mac and capture the window only.

```bash
swift testing/google-ca-55107/scripts/screens/winid.swift "iPhone Mirroring"   # window id
screencapture -x -o -l<id> out.png
testing/google-ca-55107/scripts/live-shots.sh <dir> [minutes]     # a window frame every 4 s, skipping repeats
```

Frames are named by UTC time. Review and delete frames that show personal accounts or the home screen. The AirPlay
Receiver on the Mac (port 7000) is the other route the lab used.

Not tested in the labs: QuickTime movie recording and `ffmpeg` capture of a cabled iPhone as a screen device. Try them
if the camera is not an option, and record the result here.


## Android runs

The loop for each run (`testing/android-pin-57607/TEST-PLAN.md`):

1. Factory reset, or wipe from Fleet (`fleetctl mdm wipe --host <serial>`), then delete the host in Fleet.
2. Open the fleet's company-owned enrollment link in a laptop browser (**Hosts > fleet > Add hosts > Android >
   Company-owned**). The link shows the QR code. A QR token lasts 1 hour and works once: reload it for each run.
3. Start `watch-host.sh <serial>` in a second terminal and `phone-cam.sh record <ID>` in a third.
4. On the welcome screen tap 6 times to open the QR reader, and scan. That is T0.
5. Go through the wizard at the pace the run asks for. Note every screen.
6. After the run: `fleet-activity.sh`, `server-logs.sh` (Render logs, needs `render login` and `RENDER_SERVICE_ID`).

The Android PIN project kept these scripts in its own `tools/`: `run.sh` (one test run with the evidence helpers),
`guide.sh` (on-screen steps, a countdown to the scan, and a clock with T+), `watch-host.sh` (a line each time the host,
labels, or profile status change), `fleet-activity.sh`, `server-logs.sh`, `setup-check.sh`, `host-fields.py`. Copy them
from `testing/android-pin-57607/tools/` when the next Android test starts, and keep serial numbers masked.

Facts from that project:
- Fleet sends a host's Android profiles in a per-host policy that a 30-second job assigns after enrollment. What happens in
  setup depends on when it arrives, so vary the pace.
- Fleet emits no enrollment activity for Android. Enrollment shows up only in the watch timeline.
- Android enrollment and policy messages in the server log are debug level. Turn on `FLEET_LOGGING_DEBUG=true` for the run
  and remove it afterwards.
- Manual labels survive a wipe and re-enrollment. Remove the label before the next run.


## iPhone enrollment runs (Google conditional access)

`testing/google-ca-55107/RUNBOOK.md` holds the loop: change Fleet, run the sync workflow by hand, check the phone.
GitHub started scheduled runs hours late in this repo, so start syncs by hand (`gh workflow run google-sync.yml
-f dry_run=false`). Apple Business (ADE) enrollment with end user authentication, iPads, and BYOD were not tested.
