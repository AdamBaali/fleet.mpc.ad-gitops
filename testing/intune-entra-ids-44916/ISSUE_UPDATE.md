**Update: both IDs can be read with stock osquery. The Entra path in this issue needs a correction**

- **Intune device ID:** `EntDMID` under `HKLM\SOFTWARE\Microsoft\Enrollments\<guid>\DMClient\MS DM Server`, as the workaround report reads it.
- **Entra device ID:** there is no `DeviceId` value under `CloudDomainJoin\JoinInfo`. The subkey is named after the device certificate's thumbprint, and that certificate's subject (issuer `MS-Organization-Access`) is the device ID. Fleet's own `windowsEntraIDDetails` and `windowsEntraJoinUser` detail queries read it this way.
- **Gap:** Fleet already collects the Entra device ID on Windows when Microsoft conditional access is on, but doesn't return it on the host API. That was the original ask.

**Not tested:** values on a real Entra-joined, Intune-enrolled host. Lab tests of the query logic are next.

Next: run the candidate reports in the lab, then confirm on a real host.
