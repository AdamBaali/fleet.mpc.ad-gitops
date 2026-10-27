# Draft comment for the issue (not posted; for review)

Lab results: Fleet 4.93.0, Windows 11 26H2 arm64, the provisioning package guide's package, and a fleet that requires
end user authentication. The wipe is `doWipePersistProvisionedData` sent as a custom MDM command.

**It works.**
- The host comes back by itself. About 13 minutes after the wipe, Windows is at the region screen, fleetd has
  reinstalled from the kept package, and the host is back in Fleet as the same host with MDM on and no prompt. The
  local user and their files are gone. Tested with the bypass build, the no-bypass build, a second reset, and a host
  that was off when the wipe was sent (it runs at the next check-in).
- `doWipeCloudPersistProvisionedData` works the same, in about an hour.
- Brownfield hosts work. On a host enrolled with only the MSI, a Fleet script staged the package in
  `C:\Recovery\Customizations`, and the reset applied it. This is the pattern Omnissa uses for Workspace ONE.
- The package is what brings the host back: with no package left, the host comes back without fleetd and never checks
  in.
- At first setup, the no-bypass build opens Fleet's sign-in page in Edge on the setup screen, and the host enrolls
  before any account exists.

**Gaps for the design.**
1. Repurposing. A reset host that is still in Fleet re-enrolls without end user authentication, and Fleet keeps the
   previous user as its end user. The next person is never asked to sign in.
2. To get a new user, the admin deletes the host once the wipe is acknowledged. Then the sign-in page opens at the new
   user's first desktop, not during Windows setup, and Fleet lists a new host with only the new user.
3. Fleet doesn't record the reset. Mid-reset the host shows Offline with MDM still On. Afterwards the feed shows the
   command (when it was sent) and "MDM turned on", and "Added to Fleet" shows the re-enrollment time.
4. The wipe API rejects both reprovision types with a generic "failed to unmarshal request body". If they're added to
   the built-in Wipe as is, its status would be cleared when fleetd re-enrolls (`EnrollOrbit` deletes
   `host_mdm_actions`), so "Wiped" would never show.
5. A reset host comes back in the fleet it was in, not the fleet of the package's enroll secret.
6. Rotating the enroll secret strands reset hosts whose package has the old one: fleetd retries and Fleet shows only
   an offline host. The package has to be rebuilt and staged again.
7. Permissions: the custom command needs the same role as the built-in Wipe (admin, maintainer, GitOps). Staging needs
   script permission (admin, maintainer, technician).

Questions: should a reprovision wipe clear the host's end user, or require sign-in again? And how should Fleet show
that a host was reset?

**Bug.** Once a host re-enrolls or is deleted, `fleetctl get mdm-command-results` for its wipe command fails with
"converting NULL to string is unsupported". `GetMDMWindowsCommandResults` (`server/datastore/mysql/microsoft_mdm.go`)
takes the host UUID from the MDM enrollment that ran the command, which re-enrollment removes.

**Security.** The package kept in `C:\ProgramData\Microsoft\Provisioning` is readable by every user and holds the MSI
with the enroll secret.

**Docs.** The ppkg guide's "no browser during setup" and "MDM turns on after sign-in" notes are out of date for 26H2.
The setup experience guide says the bypass needs `allow_orbit_end_user_auth_bypass: false`; the default `true` is what
makes it work. The MDM command library's Windows payloads are wrapped in `<syncml>`, which `fleetctl mdm run-command`
rejects; the bare `<Exec>` works.

Not tested: x64 hardware, BitLocker (the lab VMs have no TPM), Wi-Fi-only hosts, the Configuration Designer GUI, and a
package with an older fleetd (in progress).
