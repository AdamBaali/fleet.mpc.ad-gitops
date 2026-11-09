# Notes: where Windows stores each ID

Researched 2026-11-09. Fleet code is cited at the `fleet-v4.93.1` tag. Microsoft documents what each ID is, but not the registry layout. Registry details below come from community scripts and Fleet's code, so each one needs a check on a real host (T-4 in [TEST_PLAN.md](TEST_PLAN.md)).

## Entra device ID

| Source | osquery can read it | Evidence |
| --- | --- | --- |
| `dsregcmd /status`, field `DeviceId` | No (a command) | [Microsoft: troubleshoot with dsregcmd](https://learn.microsoft.com/entra/identity/devices/troubleshoot-device-dsregcmd) |
| `NetGetAadJoinInformation`, field `pszDeviceId` | No (a Win32 API) | [Microsoft: DSREG_JOIN_INFO](https://learn.microsoft.com/en-us/windows/win32/api/lmjoin/ns-lmjoin-dsreg_join_info). The official source |
| Subject of the device certificate in `LocalMachine\My`, issued by `MS-Organization-Access` | Yes, `certificates` | Fleet `server/service/osquery_utils/queries.go` lines 1026-1035 ([link](https://github.com/fleetdm/fleet/blob/fleet-v4.93.1/server/service/osquery_utils/queries.go#L1026-L1035)), [AADDeviceTrust `Get-AzureADDeviceID.ps1`](https://www.powershellgallery.com/packages/AADDeviceTrust.Client/1.0.0/Content/Private%5CGet-AzureADDeviceID.ps1), [AADInternals](https://aadinternals.com/post/deviceidentity) |
| `HKLM\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo\<thumbprint>` | Yes, `registry` | Points to the certificate. It does not hold the ID. [EndpointWeekly dsregcmd reference](https://endpointweekly.com/blog/whfb-dsregcmd-status-reference.html), [Nerdy Mishka](https://nerdymishka.com/articles/azure-ad-domain-join-registry-keys/) |

- The `JoinInfo` subkey is named after the device certificate's thumbprint. The values reported under it are `TenantId`, `UserEmail` and `IdpDomain`. No source lists a `DeviceId` value, so the issue's registry path is wrong.
- AADDeviceTrust reads the thumbprint from `JoinInfo`, finds that certificate in `Cert:\LocalMachine\My`, and strips `CN=` from its subject. Fleet's IdP vitals query for #44917 (`windowsEntraJoinUser`, lines 1046-1055) matches certificate to subkey the same way, which drops stale subkeys.
- Fleet's conditional access query (`windowsEntraIDDetails`, line 1033) is simpler: `SELECT subject AS device_id FROM certificates WHERE issuer LIKE 'net + windows + MS-Organization-Access%' LIMIT 1`. It runs only when Microsoft conditional access is on (line 4070), and stores the ID for conditional access, not on the host API.
- Entra registered devices (not joined) keep this certificate in the user store, per the [Entra device FAQ](https://learn.microsoft.com/entra/identity/devices/faq). Matching through `JoinInfo` avoids picking that one up.

## Intune device ID

| Source | osquery can read it | Evidence |
| --- | --- | --- |
| `HKLM\SOFTWARE\Microsoft\Enrollments\<guid>\DMClient\MS DM Server`, value `EntDMID` | Yes, `registry` | [Microsoft: DMClient CSP](https://learn.microsoft.com/windows/client-management/mdm/dmclient-csp) defines `EntDMID` as the enterprise device ID the server sets at enrollment. Path from a [Microsoft Q&A answer](https://learn.microsoft.com/en-us/answers/a/1374775) |
| Intune MDM certificate in `LocalMachine\My`, issued by `Microsoft Intune MDM Device CA`, extension OID `1.2.840.113556.5.4` | No. osquery's `certificates` table has no extension columns | [MSEndpointMgr](https://msendpointmgr.com/2024/10/12/unpacking-the-microsoft-intune-mdm-certificate/) |
| `HKLM\SOFTWARE\Microsoft\Provisioning\OMADM\MDMDeviceID\DeviceClientId` | Yes, but wrong ID | [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/836468/mdmdeviceid-after-wipe-is-missing): generated locally by Windows. Not the Intune ID |

- `EntDMID` is the only Intune source osquery can read. The customer's query uses it.
- No source says the Intune MDM certificate's subject is the device ID. Don't rely on it.

## Risks to check on a real host

- Stale enrollments. [Microsoft: diagnose MDM enrollment](https://learn.microsoft.com/windows/client-management/mdm-diagnose-enrollment) says old keys under `Enrollments` can stay after unenrollment. A query with `LIMIT 1` could return an old ID after a re-image. The candidate query returns every match plus its key, so a stale one shows up.
- Wrong subkey. [call4cloud](https://call4cloud.nl/2024/04/keeping-up-with-the-emmdeviceid-and-configrefresh-bug/) found Windows itself reading a `ConfigRefresh` subkey under `DMClient` instead of `MS DM Server`. The query names `MS DM Server` directly, so it isn't affected.
- Subject format. Fleet stores `subject` as the ID. Whether osquery on Windows renders it as the bare GUID or with `CN=` is unconfirmed. The query returns both `subject` and `common_name`.

## Lab versus production

- No Entra or Intune tenant. The lab can fake the registry keys and a certificate chain to test the SQL logic (T-1, T-2). It can't prove Windows writes them that way.
