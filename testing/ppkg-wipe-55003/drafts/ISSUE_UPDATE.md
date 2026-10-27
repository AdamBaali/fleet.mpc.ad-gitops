<!-- Draft comment for fleetdm/fleet#55003. Not posted. Paste everything below this line. -->

## Lab results: reset a Windows host with a provisioning package

| | |
|---|---|
| **Fleet** | 4.93.0, a fleet that requires end user authentication |
| **Windows** | 11 Pro 26H2 (26300.9457) arm64 |
| **Package** | Built with ICD from the [provisioning package guide](https://fleetdm.com/guides/provisioning-package) |
| **Wipe** | `doWipePersistProvisionedData`, sent with `fleetctl mdm run-command` |

### TL;DR

- The host comes back by itself. There is **no prompt to install the package after a wipe**. Windows asks
  "Is this package from a source you trust?" only once, when the package is first added at setup.
- About 13 minutes after the wipe, Windows is at the region screen with fleetd reinstalled, and the host is back in
  Fleet as the **same host** with MDM on. The local user and their files are gone.
- The gap is repurposing: the next user is never asked to sign in unless the host is deleted from Fleet first.

### What works

| Scenario | Result |
|---|---|
| Bypass build (`--bypass-end-user-auth`) | Same host back in 13 min, MDM on, no prompt |
| No-bypass build | Same host back in 13 min, no IdP sign-in |
| Second reset of the same host | Same result, same time |
| Host off when the wipe is sent | Runs at the next check-in, then as above |
| `doWipeCloudPersistProvisionedData` | Same result, about 36 min download plus 21 min reset |
| Brownfield host (enrolled with the MSI only) | A Fleet script stages the package in `C:\Recovery\Customizations`; same host back in 12.5 min |
| No package left on the host | Comes back without fleetd and never checks in. The package is what brings it back |

At first setup, the no-bypass build opens Fleet's sign-in page in Edge on the setup screen, and the host enrolls
before any account exists.

### Gaps for the design

1. **The next user isn't asked to sign in.** A reset host that is still in Fleet re-enrolls without end user
   authentication, and Fleet keeps the previous user as its end user.
2. **Getting a new user means deleting the host.** Once the wipe is acknowledged, the admin deletes the host. The
   sign-in page then opens at the new user's first desktop, not during Windows setup, and Fleet lists a new host with
   only the new user.
3. **Fleet doesn't show the reset.** During the reset the host shows Offline with MDM still On. Afterwards the
   activity feed shows the command (with the time it was sent) and "MDM turned on". "Added to Fleet" shows the
   re-enrollment time.
4. **The built-in Wipe can't send these types.** `POST /api/v1/fleet/hosts/:id/wipe` rejects both reprovision types
   with a generic `failed to unmarshal request body`. If they're added as is, the wipe status would be cleared when
   fleetd re-enrolls (`EnrollOrbit` deletes `host_mdm_actions`), so "Wiped" would never show.
5. **The host stays in its current fleet**, not the fleet of the package's enroll secret.
6. **Rotating the enroll secret strands reset hosts.** fleetd comes back but can't enroll, and Fleet shows only an
   offline host. The package has to be rebuilt and staged again.
7. **Permissions.** The custom command needs the same roles as the built-in Wipe (admin, maintainer, GitOps).
   Staging the package needs script permission (admin, maintainer, technician).

**Questions**

- Should a reprovision wipe clear the host's end user, or require sign-in again?
- How should Fleet show that a host was reset?

### Bug

Once a host re-enrolls or is deleted, getting the results of its wipe command fails:

```
fleetctl get mdm-command-results --id <command uuid>
converting NULL to string is unsupported
```

`GetMDMWindowsCommandResults` in `server/datastore/mysql/microsoft_mdm.go` takes the host UUID from the MDM enrollment
that ran the command, and re-enrollment removes that enrollment.

### Security

The package Windows keeps in `C:\ProgramData\Microsoft\Provisioning` is readable by every user, and it holds the MSI
with the enroll secret.

### Docs

- The ppkg guide's "no browser during setup" and "MDM turns on after sign-in" notes are out of date for 26H2.
- The setup experience guide says the bypass needs `allow_orbit_end_user_auth_bypass: false`. The default `true` is
  what makes it work.
- The MDM command library's Windows payloads are wrapped in `<SyncML>`, which `fleetctl mdm run-command` rejects. The
  bare `<Exec>` works.

### Not tested

- x64 hardware
- BitLocker (the lab VMs have no TPM)
- Wi-Fi-only hosts
- Packages built in the Configuration Designer GUI
- A package with an older fleetd. From the code, fleetd stays on the package's version until the fleet sets
  `update_channels` in its agent options.
