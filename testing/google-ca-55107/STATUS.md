# Status: Google conditional access session (#55107) — read by other lab sessions

Updated: 2026-10-15 20:29 CEST

## Shared resources I use
- No UTM VMs. Uses the Mac's AirPlay Receiver (port 7000, ON) once the iPhone is enrolled, and Chrome (Claude in Chrome) tabs for the Google Admin console.
- Fleet: fleet "iOS Google Lab" (fleets/ios-google-lab.yml, enroll secret not set yet, so the GitOps apply fails) and an API-only Observer user. No other fleets.
- Google side: a test Google Workspace org on a lab domain (Enterprise Standard trial), OU "Fleet iOS test" only.

## Now
Waiting on Adam for the iPhone (enroll, Google sign-in) and the repo secret. Everything prepared is in RUNBOOK.md.
