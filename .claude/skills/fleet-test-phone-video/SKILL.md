---
name: fleet-test-phone-video
description: Film or capture a phone screen with an iPhone as a Mac camera (UTC clock burned into the video), capture iPhone Mirroring windows, and run Android or iPhone enrollment tests with a timeline. Use when a Fleet test involves a phone, a setup wizard, a QR enrollment, or a screen recording.
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Phone video and phone runs

Task: $ARGUMENTS

Read `testing/_framework/guides/phones-and-video.md` now.

1. `testing/_framework/bin/clock-check.sh`: the Mac clock must match Fleet's within a second or two.
2. `testing/_framework/tools/phone-cam.sh list`, then `preview` to aim the iPhone camera at the phone under test.
3. Start the Fleet timeline in another terminal (`watch-host.sh`, from `testing/android-pin-57607/tools/`), then
   `phone-cam.sh record <ID>`. The clock in the video is UTC, like the timeline.
4. Note T0 (QR scan) and give every later time as T+mm:ss.
5. Video and frames stay in `private/video/<ID>/`. Move only chosen, cropped, masked stills into `test-evidence/`.
6. Keep device serials, accounts, and the room out of anything committed.

If the camera route isn't available, use iPhone Mirroring (`live-shots.sh`) for an iPhone, and say in the results what was
not captured.
