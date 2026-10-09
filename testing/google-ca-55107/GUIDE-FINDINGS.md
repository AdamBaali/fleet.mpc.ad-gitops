# Guide findings: Conditional access: Google (fleetdm/fleet#55107)

What the tests showed about the guide and its script, in guide order. **Fixed** means the change is on the branch
`adam/google-conditional-access-guide-tested` (fleetdm/fleet#55107 plus one commit, diff in [`proposed/`](proposed)).
Numbers are the IDs used in the testing log and test results.

## Prerequisites
| # | Finding | Evidence | Status |
|---|---|---|---|
| 31 | The script used every email Fleet has for a host. On iPhones and iPads Fleet reports two sources: `mdm_idp_accounts` (end user authentication, or an IdP username an admin set) and `custom`. Matching on the IdP email only means the Google account must be the one the user enrolled with | E-2b | **Fixed:** end user authentication is a prerequisite; the script uses `EMAIL_SOURCES=mdm_idp_accounts` by default |
| — | Business Plus has no Context-Aware Access; Enterprise Standard has it | G-1b | No change: the guide already lists the right editions |
| 22 | Gmail needs MX records on the domain. A test domain without mail can test with Drive | Notes | No change: tester note only |

## Step 1: Create a Fleet API user
| # | Finding | Evidence | Status |
|---|---|---|---|
| 10 | The step links to `fleetctl`, but `fleetctl user create --api-only` can't select endpoints. The UI can, and so can `PATCH /api/v1/fleet/users/api_only/:id` (the generic `/users/:id` returns 422) | G-2b | Not changed: same wording in the PingFederate and Duo guides. Noted in the PR |

## Step 2: Create a Google service account
| # | Finding | Evidence | Status |
|---|---|---|---|
| 12 | The delegation's client ID is the service account's **Unique ID** on its **Details** tab | G-2/G-3 | **Fixed** |
| 11 | Missing or new delegation shows as `unauthorized_client` and can take a few minutes | G-2/G-3, R-1c | **Fixed:** troubleshooting, and the script prints Google's error |
| 12b | A first Google Cloud sign-in asks for a country and the Terms of Service | G-2/G-3 | Not added: one-time and self-explanatory |

## Step 3: Sync hosts (script and workflow)
| # | Finding | Evidence | Status |
|---|---|---|---|
| 7, 16 | Partner ID with the leading C, and `customer=customers/<customer-ID>`, return HTTP 400 on the first write. Only `<id-without-C>-fleet` with `customers/my_customer` works | C-1a, C-1b | **Fixed** |
| 3 | No way to get `GOOGLE_ACCESS_TOKEN` for the dry run | R-1 | **Fixed:** the script gets its own token from `GOOGLE_CREDENTIALS` |
| 17 | `google-github-actions/auth@v2` with `access_token_subject` returns HTTP 400 `invalid_request` | G-7 | **Fixed:** no auth step; the script gets its own token |
| 9 | The workflow reuses `FLEET_API_TOKEN`, the GitOps workflow's secret (overwriting it broke GitOps applies in the #54654 lab) | G-7 | **Fixed:** `GOOGLE_SYNC_FLEET_API_TOKEN` |
| 8, 26 | If Fleet returns no emails (outage, token scope), every device would be unmanaged at once. The guard that stops this also stops the run when the only phone loses its email; the run then fails | R-1b, R-1c, E-2b R2 | **Fixed:** guard kept, run fails visibly, "No email" line per host, guide says so |
| 32 | Every "On" status counted, including `On (personal)` (BYOD) | R-1c | **Fixed:** `ENROLLMENT_STATUSES` skips BYOD by default |
| 29, 34 | The client state has `assetTags`, shown in the console. With `updateMask`, Google **appends** to `assetTags` (4 copies after 4 writes) and ignores `[]`; without it, the body replaces the state | E-2b | **Fixed:** the script writes the serial number as the asset tag, whole state, no `updateMask` |
| 13 | An old iPhone left in Google blocks the new one (one Fleet host, two Google iPhones: ambiguous) | R-1 | **Fixed:** troubleshooting |
| 30 | GitHub runs schedules best effort. In this repo, scheduled runs started hours late or not at all, also for the Duo sync with the same `2-59/5` cron | G-7, TESTING-LOG | **Fixed:** the guide says so and how to check; the script prints a summary every run |
| 27 | Matching is by email and device type. If a user's Fleet iPhone isn't signed in to Google but a personal one is, the personal one matches | R-1c | Partly: IdP email only and no BYOD narrow it. A model check isn't added (the OS version can't be used: C-2 saw 18.7 and 26.6.1 on one phone) |
| 25 | The script prints end user emails on each change, visible in Actions logs | G-7 | Not in the guide (GitOps repos are usually private). This public lab masks them |
| 28 | A second Google account on the same iPhone creates a second device record with the same Device ID; each account has its own state | C-2 | Not added: handled per account |
| 15 | A failed Google write stops the run; earlier writes are kept; the next run carries on | R-1 | Not added: acceptable |

## Step 4: Turn on the access level
| # | Finding | Evidence | Status |
|---|---|---|---|
| 18, 23 | No `device.vendors["<key>"]` form matches the Fleet state on iOS (7 forms, over 90 minutes). The keyless `device.vendors.exists(k, device.vendors[k].is_managed_device == true)` works | C-1c, C-1e | **Fixed:** the guide uses the keyless condition |
| 24 | Google rejects `contains` and lists inside `exists()`, so the condition can't be narrowed to Fleet's key. It accepts any partner that says managed | C-1e | **Fixed:** note in the guide. Open question for Google: the key for a customer-owned state |
| 19 | The level was assigned at the top-level OU including Admin Console (lockout risk) | G-8 | **Fixed:** "Don't assign it to Admin Console" |
| — | A new assignment can be in Monitor mode, which blocks nothing | G-8 | **Fixed:** "check that the assignment is Active" |
| 21 | Once, the condition box looked empty after saving | C-1c | Not added: seen once |

## Step 5: Test
| # | Finding | Evidence | Status |
|---|---|---|---|
| 20, 33 | Google applies the state within seconds both ways. UNMANAGED blocks an open app without a sign-in; MANAGED shows "Please sign in again", and reopening the app gets in | E-2b | **Fixed:** the guide says what end users see |
