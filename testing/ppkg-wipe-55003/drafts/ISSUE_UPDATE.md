<!-- Draft comment for fleetdm/fleet#55003. Not posted. Paste everything below this line. -->

## Lab results

Fleet 4.93.0, Windows 11 26H2 arm64, the [provisioning package guide](https://fleetdm.com/guides/provisioning-package)'s
package, and a fleet that requires end user authentication. Wipe: `doWipePersistProvisionedData` as a custom command.

**It works.** No prompt to install the package after the wipe; Windows asks only when the package is first added. About
13 minutes later the host is at the region screen with fleetd reinstalled, back in Fleet as the same host with MDM on.
The user and their files are gone.

Same result with and without `--bypass-end-user-auth`, on a second reset, with the host off when the wipe is sent, and
with `doWipeCloudPersistProvisionedData` (about an hour). Brownfield hosts work too: a Fleet script stages the package
in `C:\Recovery\Customizations`. With no package, the host comes back without fleetd.

### Gaps for the design

1. The next user isn't asked to sign in. Fleet keeps the previous end user unless the host is deleted after the wipe
   is acknowledged. Then sign-in happens at the new user's first desktop, not during setup.
2. Fleet doesn't show the reset: the host shows Offline with MDM On, then just "MDM turned on" in the feed.
3. The Wipe API rejects the reprovision types. If added as is, the status would be cleared when fleetd re-enrolls.
4. The host stays in its current fleet, not the fleet of the package's enroll secret.
5. Rotating the enroll secret strands reset hosts until the package is rebuilt.

**Bug:** after re-enrollment, `fleetctl get mdm-command-results` for the wipe fails with
`converting NULL to string is unsupported`.

**Security:** the kept package in `C:\ProgramData\Microsoft\Provisioning` is readable by every user and holds the
enroll secret.

Not tested: x64 hardware, BitLocker, Wi-Fi-only hosts.
