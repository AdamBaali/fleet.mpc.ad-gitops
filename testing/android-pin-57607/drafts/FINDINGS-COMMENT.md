<!-- Draft for fleetdm/fleet#57607. Not posted. Fill every {{placeholder}} from RESULTS.md, delete this line, then post. -->

**Update: requiring a PIN when company-owned Android hosts enroll ({{one-line state, e.g. "option 3 works in QR testing; zero-touch check next"}})**

> [!NOTE]
> All runs so far used **QR enrollment** on Fleet {{lab version}} with {{device models, Android versions}}. The customer
> enrolls with **zero-touch**, so this still needs a zero-touch confirmation before we call it a best practice.
> {{Zero-touch status: not run yet / run on DATE with RESULT}}

### Why `blockAfterDays: 0` is intermittent

QR and zero-touch enrollment tokens point at Fleet's default policy, which has no password settings
([service.go](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/mdm/android/service/service.go#L689-L698),
[ee service.go](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/ee/server/mdm/android/service.go#L128-L134)).
After Google reports the enrollment, a 30-second job builds the host's own policy from the fleet's profiles and moves
the device to it ([profiles.go](https://github.com/fleetdm/fleet/blob/fleet-v4.94.0/server/mdm/android/service/profiles.go#L436-L486)).
The password requirement lands on whichever setup screen the end user reached by then. {{Lab result: confirmed /
not confirmed. E.g. "In N of M runs the policy arrived on the terms screen and blocked it; in the others it arrived
before the screen lock step and Android asked for a PIN."}}

### Results

| Option | Runs | PIN prompt in setup | Blocked in setup | Time usable without a PIN | Result |
|---|---|---|---|---|---|
| 1. `blockAfterDays: 1` + user instructions | {{n or "not rerun, as reported"}} | No | No | Up to 24 h | Baseline |
| 2. `blockAfterDays: 0`, profile in the enrollment fleet | {{n}} | {{x of n}} | {{x of n}} | {{...}} | {{PASS/FAIL}} |
| 3. Enroll to a staging fleet, then move to the PIN fleet | {{n}} | {{No (by design)}} | {{x of n}} | {{min between home screen and block}} | {{PASS/FAIL}} |
| 3. Same, with a manual label instead of a fleet move | {{n}} | {{...}} | {{...}} | {{...}} | {{PASS/FAIL}} |
| `BLOCK_SCOPE_DEVICE` variant (optional) | {{n or "not run"}} | {{...}} | {{...}} | {{...}} | {{...}} |

Per-run details (device, Android version, timings, the screen where the policy arrived):
[RESULTS.md](https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/testing/android-pin-57607/RESULTS.md) ·
evidence: [EVIDENCE.md](https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/testing/android-pin-57607/EVIDENCE.md)

The profile we tested (device-scope PIN, 6+ digits, no repeating or ordered sequences, block at once, wipe after 30
days with factory reset protection kept):

```json
{
  "passwordPolicies": [
    { "passwordScope": "SCOPE_DEVICE", "passwordQuality": "NUMERIC_COMPLEX", "passwordMinimumLength": 6 }
  ],
  "policyEnforcementRules": [
    {
      "settingName": "passwordPolicies",
      "blockAction": { "blockAfterDays": 0 },
      "wipeAction": { "wipeAfterDays": 30, "preserveFrp": true }
    }
  ]
}
```

### Recommendation

{{Pick one and delete the others.}}

- **If option 2 passed every run:** keep the password profile in the zero-touch fleet with `blockAfterDays: 0`. No extra
  parts. {{caveats}}
- **If option 3 (fleet move) passed:** point the zero-touch configuration at a staging fleet with no password profile.
  Move each host to the fleet with the password profile once setup is done. Fleet doesn't emit an enrollment activity
  for Android, so the move is an API automation that polls the staging fleet and moves hosts that enrolled more than
  {{N}} minutes ago (`POST /api/v1/fleet/hosts/transfer`). A wiped host enrolls back into staging, because Fleet takes
  the fleet from the enrollment configuration. End users can use the device without a PIN for {{measured gap}}.
- **Label instead of a fleet move:** {{works / not recommended}}. Manual labels stay on a host after a wipe, so a reset
  device gets the password profile at enrollment again (the option 2 race) unless the automation removes the label
  first. The fleet move doesn't have this problem.
- **If nothing is reliable:** {{fallback, e.g. option 1 with user instructions}}, and a product change so the
  enrollment token's policy already holds the fleet's profiles (details below).

### Other things to know

- Google requires a `wipeAction` with every `blockAction`. With no rule at all, Google's default blocks a non-compliant
  device at once and factory resets it after 10 days without keeping factory reset protection. Worth checking the
  customer's current profile for this.
- Keep `passwordPolicies` and `policyEnforcementRules` in the same profile. Fleet merges profiles by top-level key, so
  a second profile with `policyEnforcementRules` replaces the first one's rules.
- {{anything else from RESULTS.md findings}}

### Possible product change

Put the fleet's profiles in the policy the enrollment token names, so the password requirement is on the device from
the first moment of management instead of arriving partway through setup. Untested: needs a Fleet change.
{{Link a feature request here if one is filed.}}

**Next:** {{zero-touch confirmation with a device registered through OEM Test Reseller / customer review}}
