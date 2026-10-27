# Draft comment for the issue (not posted; for review)

Lab results on Windows 11 26H2 arm64 with the provisioning package guide, a fleet that requires end user
authentication, and `doWipePersistProvisionedData` sent from Fleet as a custom MDM command:

- **The host comes back by itself.** About 13 minutes after the wipe, Windows is at the region screen, fleetd has
  reinstalled from the kept package, and the host is back in Fleet as the same host, with MDM on and no prompt.
  The local user and their files are gone. Tested with the bypass build, the no-bypass build, and a second reset of
  the same host. The cloud variant (`doWipeCloudPersistProvisionedData`) works the same, in about an hour.
- **Brownfield hosts work too.** On a host enrolled with only the MSI, a Fleet script copied the package into
  `C:\Recovery\Customizations`. After the wipe, the reset applied it and the host came back the same way. This is
  the pattern Omnissa uses for Workspace ONE.
- **Repurposing gap.** With the no-bypass build, a reset host that is still in Fleet re-enrolls without end user
  authentication, and Fleet keeps the previous user as the host's end user. The next person is never asked to sign in.
- **Deleting the host fixes attribution, with a catch.** If the admin deletes the host once the wipe is acknowledged,
  Fleet blocks enrollment after the reset. Nothing appears during Windows setup; the sign-in page opens at the new
  user's first desktop. After sign-in Fleet lists a new host with only the new user.
- **First setup is different.** When the package is applied at the region screen, fleetd opens the sign-in page in
  Edge on the setup screen, and the host enrolls before any account exists.

Product questions this raises: should a reprovision wipe clear the host's end user (or require sign-in again), and
should Fleet show that a host was wiped by a custom command? Today the activity feed shows the command and a new
"MDM turned on", and nothing else.

Bug: after a host re-enrolls, reading its wipe command's result fails ("converting NULL to string is
unsupported"): the results query gets the host UUID from the old MDM enrollment.

Doc fixes found on the way: the guide's "no browser during setup" note, the MDM-after-sign-in note, the bypass setting
in the setup experience guide (says `false`, should be `true`), and the Windows command library payloads (Fleet only
accepts the bare `<Exec>`).

Not tested: x64 hardware, BitLocker on, Wi-Fi-only hosts, enroll secret rotation.
