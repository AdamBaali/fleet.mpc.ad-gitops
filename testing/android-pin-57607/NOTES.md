# Notes: Android PIN at enrollment (fleetdm/fleet#57607)

Research done before the lab runs. Fleet code is cited at `fleet-v4.94.0` (the latest release on 2026-11-04). The
same lines were checked on `main` (6051ca4). Check the customer's Fleet version and re-check these links at its tag.

## Fleet behavior that matters here

- **Profiles reach the host after enrollment, not with it.** QR and zero-touch tokens name the default policy
  `policies/1` ([service.go#L689-L698](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/mdm/android/service/service.go#L689-L698),
  [ee service.go#L128-L134](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/ee/server/mdm/android/service.go#L128-L134)).
  That policy has status reporting only ([service.go#L378-L393](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/mdm/android/service/service.go#L378-L393)).
  The fleet's profiles arrive in a per-host policy that a 30-second cron job builds and assigns
  ([cron.go#L2299-L2306](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/cmd/fleet/cron.go#L2299-L2306),
  [profiles.go#L436-L486](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/mdm/android/service/profiles.go#L436-L486)).
  This is the likely cause of the intermittent "blocked by your work policy": the timing depends on the wizard.
- **Profiles merge by top-level key.** Fleet sorts a host's profiles by name and the last one wins for each top-level
  key; the overridden profile shows Failed with "overridden by another configuration profile"
  ([profiles.go#L233](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/mdm/android/service/profiles.go#L233),
  [#L380](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/mdm/android/service/profiles.go#L380)).
  So `passwordPolicies` and `policyEnforcementRules` go in one profile, and no other profile in the fleet may set
  `policyEnforcementRules`, or one of the two loses all of its rules.
- **`setupActions` is rejected** in Android profiles ([android.go#L62](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/fleet/android.go#L62)).
- **Re-enrollment takes the fleet from the token.** A wiped host that enrolls again lands in the fleet of the QR or
  zero-touch configuration it used, not its previous fleet ([pubsub.go#L843](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/mdm/android/service/pubsub.go#L843)).
  Good for option 3 with a fleet move: a reset device goes back through staging.
- **Manual labels survive re-enrollment** ([android-mdm-setup.md#L57](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/articles/android-mdm-setup.md?plain=1#L57)).
  With the label variant of option 3, a reset device keeps the label, so its profile is present at enrollment again:
  the same race as option 2. The automation would have to remove the label before every wipe. This favors the fleet
  move over the label.
- **No Android enrollment activity.** Fleet doesn't emit an enrollment activity for Android hosts
  ([pubsub.go, "Enrollment activities are intentionally not emitted for Android"](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/mdm/android/service/pubsub.go#L1075)),
  so an activity webhook can't start the option 3 move. A production automation would poll the staging fleet
  (`GET /api/v1/fleet/hosts?fleet_id=<staging>`, keeping Android hosts) and move hosts that enrolled more than N minutes
  ago. Check in O3F that `last_enrolled_at` or `created_at` is set for Android hosts before relying on it.
- **Labels in GitOps.** A manual label with no `hosts:` key keeps its membership on each apply
  ([yaml-files.md#L44](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/docs/Configuration/yaml-files.md?plain=1#L44)).
  If the instance has the labels exception on, any `labels:` key fails the apply; `fleets/android-pin-label.yml` would
  then need the label made in the UI instead.

## Zero-touch in the lab

- **The lab has no zero-touch customer account.** The portal (`enterprise.google.com/android/zero-touch/customers`)
  returns 403 for the lab Google account. Only a reseller creates a customer account, and the OEM Test Reseller step in
  Fleet's guide is done from inside an existing account
  ([android-zero-touch-enrollment.md](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/articles/android-zero-touch-enrollment.md)).
- **Fleet 4.94.0 can target a fleet.** The zero-touch setup page in the lab has a fleet picker, and the code takes a
  `fleet_id` when it creates the token ([ee service.go#L82-L95](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/ee/server/mdm/android/service.go#L82-L95)).
  The guide at that tag still says all zero-touch hosts enroll to Unassigned. Check which fleet a zero-touch host
  lands in during the Z tests.

## Google (Android Management API) facts

Sources: the [Policy reference](https://developers.google.com/android/management/reference/rest/v1/enterprises.policies),
the discovery document (`https://androidmanagement.googleapis.com/$discovery/rest?version=v1`, fetched 2026-11-04), and
[compliance](https://developers.google.com/android/management/compliance).

- `passwordPolicies[]` is the current field. `passwordRequirements` is deprecated.
- `passwordScope` unset means the whole device on a fully managed host. The profiles set `SCOPE_DEVICE` to be explicit.
- `NUMERIC_COMPLEX`: digits with no repeating (4444) or ordered (1234) sequences. `passwordMinimumLength` applies to it.
- `BlockAction.blockAfterDays`: "To block access immediately, set to 0." `BlockAction` says "wipeAction must also be
  specified", and `wipeAfterDays` must be greater than `blockAfterDays`. Google recommends no more than 30 for either.
- `BlockAction.blockScope`: `BLOCK_SCOPE_WORK_PROFILE` (the default) or `BLOCK_SCOPE_DEVICE`, "only applicable to
  devices that are company-owned". This is the only other `BlockAction` option, hence `pin-blockaction-device.json`.
- `WipeAction.preserveFrp`: keep factory reset protection data on wipe. The profiles set `true`.
- **Default rule:** with no enforcement rule, a `passwordPolicies` violation blocks the device at once, and a device
  still non-compliant after 10 days is factory reset without keeping factory reset protection data. So
  `blockAfterDays: 0` behaves like having no rule, apart from the wipe settings. Any customer profile without a
  rule has the 10-day wipe.
- Non-compliance reason `USER_ACTION` is what Fleet shows as Failed until the end user sets a PIN.

## The JSON in the issue's screenshot

The screenshot in fleetdm/fleet#57607 is a suggested policy, not the customer's profile. It sets `passwordRequirements`
and a `complianceRules` entry with `nonComplianceDetailCondition.nonComplianceReason: PASSWORD_NOT_SET` and a
`blockAction`. Checked against the discovery document (2026-11-05), it wouldn't work as written:

- `ComplianceRule` has only `apiLevelCondition`, `disableApps`, `nonComplianceDetailCondition` and
  `packageNamesToDisable`. It has no `blockAction`.
- `PASSWORD_NOT_SET` isn't a value in the API.
- `passwordRequirements` is deprecated in favor of `passwordPolicies`.

The working form of the issue's BlockAction fallback is `policyEnforcementRules` with `settingName: passwordPolicies`,
`blockAction` and `wipeAction`, which is what `pin-block-0.json` uses. So the fallback is already what the O2 runs test.

## Google's provisioning guidance

- **Google: the policy at enrollment shapes the setup screens.** The provisioning guide says "Policies can impact
  the generation of the UI during device provisioning", password policies first. For password steps in setup, it
  suggests keeping the device in quarantine (enrolled with no policy) until the final policy is linked. It recommends
  naming that policy in the enrollment token (`policyName`). A device left in quarantine for 5 minutes is factory
  reset ([provision-device](https://developers.google.com/android/management/provision-device), checked 2026-11-06).
  Fleet names a default policy with no password settings, so setup is built without a PIN step and the PIN settings
  arrive mid-wizard. This backs the product ask below.
- **No public reports of the Pixel block.** A search on 2026-11-06 found no Google doc, Reddit thread or vendor forum
  post about "Blocked by work policy" on a Pixel's "Additional legal terms" screen. Microsoft's Intune guidance for
  fully managed Android says the same as Google: a password profile assigned before enrollment applies during setup,
  and one assigned after it doesn't prompt in setup
  ([Microsoft Learn](https://learn.microsoft.com/en-us/troubleshoot/mem/intune/device-configuration/assign-password-setting-android-fully-managed)).

## Product ask, if no option is reliable

Put the fleet's profiles in the policy the enrollment token names (a per-fleet policy, or the host policy created
before the token is used), so the password requirement is on the device from the first moment of management instead
of arriving mid-wizard. Google lets a token name any policy ("When creating a token you can specify a policy that will
be applied to the device", [codelab](https://developer.android.com/codelabs/android-management-api), section 7).
Whether Android then asks for the PIN in a fixed place in setup is untested: the lab can't try it without a Fleet change.

The same codelab (section 9) shows the option 3 behavior: after a password policy is added to a device that's already
set up, "In a few seconds you should see a screen that will ask you to set a password, stopping you from using the
device until you do so."

## Lab versus production

- **Capturing the setup wizard.** adb can't: a factory reset turns USB debugging off, and the Samsung refused adb
  commands even before the reset ("error: closed"). Screenshots on the phone can't be copied off either: Fleet's
  policy doesn't set `deviceConnectivityManagement.usbDataAccess`, and Google's default for company-owned devices is
  `DISALLOW_USB_FILE_TRANSFER` (the phone shows "controlled by admin"). The lab uses an iPhone camera instead
  (`tools/cam-log.sh`, one frame a second) and adds no lab-only profile, so the policy matches what the customer's
  hosts get.

- QR, not zero-touch. Both use the default policy at enrollment, so the race should be the same (Z tests confirm).
- Test devices and Android versions differ from the customer's. Record both per run.
- No apps are deployed in the lab fleets. Blocking is checked on built-in apps (Chrome, Play Store, Camera).
- Lab Fleet version may differ from the customer's. Record it.

## Not tested yet

Everything in TEST-PLAN.md. Profiles passed the repo validator and a key, type and enum check against the discovery
document. Fleet's own validation runs in the PR dry run.
