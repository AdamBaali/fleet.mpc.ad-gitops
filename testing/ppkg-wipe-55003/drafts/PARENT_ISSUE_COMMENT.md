# Draft comment for the parent issue (not posted; for review)

Tested the reset-for-a-new-user flow end to end: Fleet 4.93.0, Windows 11 26H2, the package from our provisioning
package guide, and a fleet that requires end user authentication. Fleet sends `doWipePersistProvisionedData` as a
custom MDM command.

**Does it prompt to install the package after a wipe? No.** Windows asks "Is this package from a source you trust?"
only once, when the package is first added at setup. After the wipe, Windows re-applies the package by itself during
the reset. The host comes back at the region screen with fleetd already installed and running, and nobody touches it.

**Main findings**

1. **The host comes back on its own.** About 13 minutes after the wipe the host is back in Fleet as the same host, with
   MDM on. The user and their files are gone. Same result with and without `--bypass-end-user-auth`, on a second reset,
   and when the host was off when the wipe was sent (it runs at the next check-in). `doWipeCloudPersistProvisionedData`
   works the same in about an hour.
2. **Hosts that weren't set up with the package work too.** A Fleet script copies the package into
   `C:\Recovery\Customizations`, and the reset applies it from there. With no package on the host, it comes back
   without fleetd and never checks in again.
3. **The next user isn't asked to sign in.** A host that is still in Fleet re-enrolls without end user
   authentication and keeps the previous user as its end user. To get the new user, the host has to be deleted from
   Fleet after the wipe is acknowledged. Then the sign-in page opens at the new user's first desktop, not during
   Windows setup.
4. **Fleet doesn't show the reset.** During it, the host shows Offline with MDM still On. Afterwards the feed shows the
   command and "MDM turned on", and "Added to Fleet" resets to the re-enrollment time. The built-in Wipe action can't
   send these wipe types today. If they're added as they are, its status would be cleared when fleetd re-enrolls.
5. **Enroll secret rotation strands hosts.** If the fleet's secret changes after the package was built, fleetd comes
   back after the reset but can't enroll, and Fleet shows only an offline host. The package has to be rebuilt.
6. **The host stays in its current fleet**, not the fleet of the package's enroll secret.
7. **Bug:** after the host re-enrolls, `fleetctl get mdm-command-results` for the wipe fails with "converting NULL to
   string is unsupported".
8. **Security:** the package Windows keeps in `C:\ProgramData\Microsoft\Provisioning` is readable by every user, and it
   holds the MSI with the enroll secret.

Not tested: x64 hardware, BitLocker, Wi-Fi-only hosts.
