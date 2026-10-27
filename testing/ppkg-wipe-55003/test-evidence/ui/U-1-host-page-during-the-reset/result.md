# U-1: Host page during the reset

- **Started:** 2026-10-27T09:40:08Z
- **Objective:** Fleet host page while the host resets
- **Expected:** Captured; record what Fleet shows mid-reset

## Steps and evidence

Evidence: X-4 010-fleet-host-mid-reset.jpg (host 29, 10 minutes into its reset) and the fleet-poll.log of every reset test. Fleet shows the host Offline, with MDM status still "On (manual)" and connected_to_fleet true, the old hostname, and "Last fetched" from before the wipe. Nothing says a wipe is in progress.

## Result: PASS

Mid-reset Fleet shows Offline with MDM still On (manual) and connected; nothing marks the reset

_Finished 2026-10-27T09:40:08Z_
