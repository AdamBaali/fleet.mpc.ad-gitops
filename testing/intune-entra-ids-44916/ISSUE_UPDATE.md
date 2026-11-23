**Update: both IDs can be read with stock osquery. The Entra path in this issue needs a correction**

- **Intune device ID:** `EntDMID` under `HKLM\SOFTWARE\Microsoft\Enrollments\<guid>\DMClient\MS DM Server`, as the workaround report reads it.
- **Entra device ID:** there is no `DeviceId` value under `CloudDomainJoin\JoinInfo`. The subkey is named after the device certificate's thumbprint, and that certificate's subject (issuer `MS-Organization-Access`) is the device ID. Fleet's own `windowsEntraIDDetails` and `windowsEntraJoinUser` detail queries read it this way.
- **Gap:** Fleet already collects the Entra device ID on Windows when Microsoft conditional access is on, but doesn't return it on the host API. That was the original ask.

- **Lab:** both report queries return the right IDs on a Windows 11 VM with faked keys and certificates, and ignore a missing certificate, a non-Entra issuer and an older join. A second Intune enrollment returns two rows, each with its key, so a stale one stays visible.

**Not tested:** values on a real Entra-joined, Intune-enrolled host, and which enrollment Windows keeps after a re-image.

- **API:** with both reports stored in a lab fleet, `GET /api/v1/fleet/reports/:id/report` and `GET /api/v1/fleet/hosts/:id/reports/:id` return the right IDs per host, and `report_clipped` stays false.

Next: confirm on a real Entra-joined, Intune-enrolled host.
