# E-1b: PKG-B at the region screen

**Objective:** Apply the bypass package during setup on a fresh generalized clone in fleet 10 (end user authentication on)  
**Expected:** Enrolls during setup with no prompt; MDM On before any user account  
**Run:** 2026-10-26T18:46:52Z to 2026-10-26T18:51:06Z

## Evidence

- `01-region-screen.png`, `02-trust-prompt.png` (VM screens): package opened from Shift+F10; Windows asks "Is this package from a source you trust?"
- `03-privacy-1.png`, `04-privacy-2.png`, `05-desktop-lab1.png` (VM screens): rest of setup as `lab1`
- `06-fleet-host.txt`: host in Fleet

## What happened

"Yes, add it" at 18:48:33 UTC. Host 23 enrolled in fleet 10 and showed MDM On at 18:48:56, 23 s later, before any user
account existed. Setup finished as `lab1` with no other prompt.

## Result: PASS

Bypass build: enrolled and MDM On during setup with no prompt; the `lab1` desktop came up with no prompt.
