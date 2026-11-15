---
name: fleet-test-phone-video
description: Record a phone screen with an iPhone camera, a UTC clock, and a live view, and run Android or iPhone enrollment tests with a timeline. Use when a Fleet test involves a phone, a setup wizard, a QR enrollment, or a screen recording.
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Phone video

Task: $ARGUMENTS

Read `testing/_framework/guides/phones-and-video.md`. Run `bin/clock-check.sh`, start the Fleet timeline, then
`tools/phone-cam.sh record <ID>`. Note T0 and give times as T+. Video stays in `private/video/`. Only chosen, cropped,
masked stills go in `test-evidence/`.
