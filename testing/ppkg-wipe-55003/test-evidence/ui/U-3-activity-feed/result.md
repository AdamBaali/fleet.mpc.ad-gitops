# U-3: Activity feed

**Objective:** Host activity after a custom wipe  
**Expected:** Captured with timestamps  
**Run:** 2026-10-27T09:40:08Z to 2026-10-27T09:40:08Z

## Evidence

## What happened

Evidence: X-2 008-fleet-activity-after.jpg (admin name masked). The feed has two entries per reset: "<admin> ran
.../`doWipePersistProvisionedData` as a custom MDM command on this host" at the time it was sent, and "Mobile device
management (MDM) was turned on for this host" when Windows re-enrolled. In X-2 the host was off, so the command entry is
an hour older than the reset. No entry for the reset itself, the re-enrollment of fleetd, or the end user change.

## Result: PASS

Two entries per reset: the custom command when sent and MDM turned on; nothing for the reset or re-enrollment.
