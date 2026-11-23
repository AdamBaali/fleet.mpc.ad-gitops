Nice work on this. I ran it in our lab on a fresh Windows 11 arm64 VM (26300) against Fleet 4.95, as a saved script, and most of it held up well:

- Rerun on an enrolled host: exit 0 in 4 s, no changes.
- Host with no MDM: it waited for Fleet to show MDM Off, enrolled with `RegisterDeviceWithManagement` (0x00000000), and confirmed the first session. Exit 0 in about a minute, and it beat fleetd to the enroll.
- The `ConnInfo\LastSessionResult` and `AddrInfo\Addr` values you check are there on a Fleet enrollment, so the health check works.
- The AutoEnrollMDM Group Policy check stops it with exit 2 and changes nothing.
- It enrolled fine at the region screen with no user signed in.

I couldn't test the Intune unenroll itself (no Intune tenant), so the old MDM was either a removed Fleet enrollment or a fake leftover key.

One thing I'd change before merge:

**Leftover enrollment keys strand the host.** I added a key like an old MDM leaves behind (UPN and discovery URL, `EnrollmentState` 3, no OMADM account). The script listed it under "MDM enrollments before" with `FleetSeesOn True`, went on to step 2, and only then exited 5. After a refetch, Fleet reported "On (manual) Intune" while the host had no MDM, and fleetd didn't enroll it. With a real Intune enrollment, step 2 would already have removed Intune at that point. Could the `FleetSeesOn` check for keys other than the active enrollment move into preflight, so it exits before anything changes? Removing the key and rerunning recovered the host in 25 s, so the exit 5 message could point at `fix-windows-mdm-migration.ps1` too.

Smaller things:
- **Saved script only.** At 17.6k characters it's over the 10,000-character limit for scripts pasted into Run script (Fleet returns 422). As a saved script it runs. Worth a line in the header.
- **Errors after the unenroll.** Once the old MDM is gone, a one-off error goes to the catch block and exits 7 (for example reading `identifier` while fleetd rewrites it, or a proxy returning HTML). Retrying there might be safer. I didn't reproduce this one.
- **Enroll step and manual mode.** With programmatic enrollment on, fleetd would also enroll once Fleet shows Off. Your enroll step is what makes it work when "Turn on MDM programmatically" is off. A line in the header saying so would help.
- **Staged rollout docs.** The issue also asked for the rollout to be written up, including turning off automatic migration first, since that setting is global.

Happy to rerun it in the lab after changes. The VM is still up.
