# Personal phones with Fleet and Okta: research and checks

This folder holds research for `customer-mozartia`.
- **Today:** they run Fleet with Auth0 as their single sign-on. Fleet has no IdP connected. They plan to move to Okta at the end of 2027.
- **Their goal:** personal phones with work and personal data kept apart. iPhone and Android come first, and personal laptops may follow.
- **Apple Business:** Managed Apple Accounts aren't turned on, and they don't want to disrupt users.
- **Android:** they want to move off Google endpoint management.

The draft reply is in [RESPONSE-DRAFT.md](RESPONSE-DRAFT.md). Names and internal links are in `private/`, which git ignores.

## What changed after the second check

| First draft said | Corrected to | Why |
|---|---|---|
| Fleet's IdP works with Auth0 today | Fleet supports any SAML IdP, but the customer has none connected, and Auth0 hit limits before | Customer Slack, July 2026 |
| Fleet uses "the email" for the Managed Apple Account | Fleet uses the SAML Name ID. It must be the user's email | Code row 1 |
| Federation is required | Federation is optional. Without it, users have a separate Apple password | Apple, account-driven enrollment |
| Verifying the domain sends notices, and users get 60 days | Starting Domain Capture sends the notices. Users get 30 days, and capture can't be undone | Apple, capture a domain |
| Android has one work profile per device | "Remove the old work profile first". Google doesn't document a one-profile limit | Google docs |
| Okta Verify works on User Enrollment | Okta documents managed phones only. Lab test needed | Okta docs |
| The same email keeps the host link after an IdP change | Only if the Name ID string is the same. Otherwise Fleet creates a new account | Code row 3 |

## Checked in Fleet code (`fleetdm/fleet` main at `dc2161d163`)

| # | Claim | Result | Evidence |
|---|---|---|---|
| 1 | The account-driven profile's `AssignedManagedAppleID` comes from the IdP | True. The value is the SAML Name ID. Fleet doesn't compare it with what the user types on the device | `ee/server/service/mdm.go:1499-1503`, `server/sso/authorization_response.go:50-54`, `server/mdm/apple/apple_mdm.go:1417` |
| 2 | IdP settings are global | True. Account-driven enrollment needs the global IdP. It doesn't read the fleet's toggle | `server/fleet/app.go:287`, `ee/server/service/mdm.go:1106-1158` |
| 3 | IdP change keeps the host link | Only if the Name ID string matches (case-insensitive). Otherwise Fleet creates a new account | `server/datastore/mysql/apple_mdm.go:3888-3899`, `schema.sql` `host_mdm_idp_accounts` |
| 4 | `only_allow_apple_business_enrollment` blocks account-driven enrollment | True | `ee/server/service/apple_mdm.go:34-36, 55-57` |
| 5 | Data on personal iPhones | Device name, capacity, OS version, product name, time zone, managed apps only, managed certificates. No serial, UDID, IMEI, phone number, or location | `server/mdm/apple/commander.go:474-484` |
| 6 | Lock and wipe on personal iPhones | Blocked in the backend and hidden in the UI | `ee/server/service/hosts.go:72-75, 296-299` |
| 7 | `$FLEET_VAR_HOST_UUID` on personal iPhones | Resolves to Apple's Enrollment ID | `server/mdm/lifecycle/lifecycle.go:151-157`, `server/mdm/apple/install_application.go` |
| 8 | VPP on personal iPhones | Yes, with user-based licenses tied to the Managed Apple Account | `ee/server/service/software_installers.go:2134-2207` |
| 9 | Account-driven enrollment on macOS | No. The server rejects anything other than iPhone, iPad, and iPod | `server/service/apple_mdm.go:2901-2910` |
| 10 | Android personal wipe | Hidden in the UI. Allowed in the API, where it removes the work profile only | `ee/server/service/hosts.go:333-337` |
| 11 | Fleet policy-based Okta conditional access | macOS only | `articles/okta-conditional-access-integration.md`, `server/datastore/mysql/policies.go:3251` |

## Checked in vendor docs

| Claim | Result | Source |
|---|---|---|
| Account-driven enrollment needs a Managed Apple Account. Federation is optional | True | [Apple](https://support.apple.com/guide/deployment/account-driven-enrollment-methods-dep4d9e9cd26/web) |
| Domain Capture notifies people with personal accounts on the domain. They get 30 days, then a temporary address. Capture can't be undone | True | [Apple](https://support.apple.com/guide/business/capture-a-domain-axm512ce43c3/web) |
| _Supervised devices only_ blocks personal phones | True. Whether _Managed devices only_ allows User Enrollment is inferred. Test it | [Apple](https://support.apple.com/en-gb/guide/business/axm53xk34bq/web) |
| On User Enrollment, MDM can't see identifiers, location, or personal apps, and can't erase the device | True | [Apple](https://support.apple.com/guide/deployment/user-enrollment-and-mdm-dep23db2037d/web), `apple/device-management` schema |
| Managed Open In and managed pasteboard restrictions work on User Enrollment | True (`requireManagedPasteboard` needs iOS 15 or later) | `apple/device-management` `com.apple.applicationaccess.yaml` |
| MDM can't take over an app the user installed | True (`ChangeManagementState` is forbidden on User Enrollment) | `apple/device-management` `application.install.yaml` |
| Custom IdP federation needs OIDC and Shared Signals. SCIM is optional | True | [Apple](https://support.apple.com/guide/business/axmb19317543/web) |
| Auth0 supports Apple Business federation | No documentation found | Auth0 docs search |
| Okta device assurance on iOS: OS version, lock screen, jailbreak | True | [Okta](https://help.okta.com/oie/en-us/content/topics/identity-engine/devices/device-assurance-add.htm) |
| Okta: user-driven enrollment has no UDID, so use a generated ID | True. Okta doesn't mention User Enrollment by name | [Okta](https://help.okta.com/oie/en-us/content/topics/identity-engine/devices/managed-app-configs-ios.htm) |
| Okta SSO extension on User Enrollment | Apple allows the payload. Okta doesn't document it | [Okta](https://help.okta.com/oie/en-us/content/topics/identity-engine/devices/config-credential-sso-ext-ios.htm) |

## Learned from other customers (Fleet Slack)

- VPP installs on personal iPhones break if the user's name changes in Apple Business or the IdP (bug #55468).
- On iPhone, Okta Verify in the personal space can still use FastPass for work apps. Enforce controls per app as well.
- Before 4.93, Fleet listed personal apps on personal iPhones (#52701, fixed). The customer runs 4.93.2.
- Android app configuration can't use `$FLEET_SECRET_*` yet (#51977), so the Okta key for Android is stored as plain text.

## Related issues in `fleetdm/fleet`

- #53817: account-driven enrollment for macOS (open). Blocks personal laptops.
- #44973: Entra conditional access for iOS and Android (open). No Okta equivalent found.
- #55468: personal iPhone app installs fail after a name change (open bug).
- #55278: the API shows lock and wipe as allowed on personal iPhones, though they're blocked (open bug, 4.95).
- #51977: secrets in Android app configuration (open).
- #52285: bring back the "On (personal)" status (open, 4.94).

## Still to test in the lab

1. Okta Verify management attestation on a personal iPhone, and which ID Okta records for `$FLEET_VAR_HOST_UUID`.
2. Apple Business _Managed devices only_ with a personal iPhone.
3. An IdP cutover with the same Name ID: the host keeps its link, and VPP installs keep working.
4. What iOS shows when the assigned Managed Apple Account differs from the one the user types.
5. Whether manually created Managed Apple Accounts keep working after federation is turned on later.
6. The Okta Credential SSO extension on a personal iPhone.

## Docs findings for Fleet

- `articles/apple-mdm-setup.md:51` says account-driven enrollment supports macOS. The code rejects macOS.
- The account-driven enrollment guide says the fleet must have end user authentication on. The code checks only the global IdP setting.
