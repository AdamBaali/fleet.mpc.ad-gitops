# Lab IdP for Fleet end user authentication

The lab Fleet has no IdP for end users today (`default.yml` has no `mdm.end_user_authentication`). The E and W tests
need one so we can see Fleet's sign-in page, the IdP login, and the user Fleet links to the host.


## Choice: Okta Integrator Free org

| Option | For | Against |
|---|---|---|
| **Okta Integrator Free org** (chosen) | Free, no expiry, the IdP most customers use, Fleet's guides cover it, reusable for the Okta phone tests in `../byod-ios-okta/` | Adam creates the account by hand |
| Keycloak in Docker on the Mac | No account, fully scripted | Not what customers run. The VM must reach the Mac. Fleet can't fetch a metadata URL from the Mac, so metadata goes in as XML |
| Microsoft Entra ID | Matches Windows customers | Needs a tenant. Entra users would push toward Entra join, which skips the ppkg path |

SAML is a browser redirect. Only the VM's browser has to reach the IdP. Fleet only fetches the metadata URL.


## Steps

Adam does steps 1 and 3 (account creation and passwords). Record the org URL and user emails in `private/idp.md`,
never in a committed file.

1. Sign up for an Okta Integrator Free Plan org at `developer.okta.com`. Sign in to the Admin Console.
2. **Applications > Applications > Create App Integration > SAML 2.0**. Name: `Fleet end users (lab)`.
3. **Directory > People > Add person**: two test users, `eua-user-1` and `eua-user-2`, with a real mailbox you
   control (plus addressing works). Set a password, no activation email needed.
4. SAML settings:

   | Field | Value |
   |---|---|
   | Single sign-on URL | `https://fleet.mpc.ad/api/v1/fleet/mdm/sso/callback` |
   | Use this for Recipient URL and Destination URL | On |
   | Audience URI (SP Entity ID) | `fleet-mpc-ad-end-users` (must equal `entity_id` in `default.yml`) |
   | Name ID format | EmailAddress |
   | Application username | Email |
   | Attribute statement | `name` = `user.displayName` (Fleet reads the full name from `name`) |

5. **Assignments**: assign both test users.
6. **Sign On** tab: copy the **Metadata URL**. Add it as repository secret `FLEET_EUA_METADATA_URL`
   (`gh secret set FLEET_EUA_METADATA_URL`), and add the line to `.github/workflows/workflow.yml` `env:`.
7. Optional: an app sign-in policy that disallows FastPass, as Fleet's setup experience guide recommends for Okta.
   The VM has no Okta Verify, so this only avoids a dead "Use Okta FastPass" button.
8. Check: **Sign On > SAML Signing Certificates > View SAML setup instructions**, then Preview SAML. Name ID is the email.

Sources: Fleet `articles/setup-experience.md` ("Require IdP authentication", callback URL and Name ID) and
`docs/Configuration/yaml-files.md` (`end_user_authentication`), both at `fleet-v4.93.2`.


## In Fleet (through GitOps, S-2)

```yaml
org_settings:
  mdm:
    end_user_authentication:
      idp_name: Okta (lab)
      entity_id: fleet-mpc-ad-end-users
      metadata_url: $FLEET_EUA_METADATA_URL
```

Then `controls.setup_experience.enable_end_user_authentication: true` in `fleets/windows-reset-lab.yml` only.
Other fleets keep it off, so their hosts see no change.


## What the end user should see (no bypass)

1. At the desktop, fleetd opens the default browser to Fleet's sign-in page.
2. Fleet redirects to Okta. The user signs in as a test user.
3. Okta posts back to `/api/v1/fleet/mdm/sso/callback`. Fleet links the IdP account to the host's UUID.
4. fleetd enrolls. Host details show the user under **Device user**.


## Teardown

Unassign and deactivate the test users, delete the SAML app, remove `end_user_authentication` from `default.yml`,
delete the secret. Keep the org if the phone tests still need it.
