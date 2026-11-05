<!-- Draft reply to customer-antonella in their shared Slack channel. Not posted. Adam reviews and posts. -->

Thanks, agreed: landing on a home screen full of greyed-out apps with no reason given is confusing. Two things help
today, and the real fix is in progress.

**1. Tell end users why, right where they get stuck.** Add this profile to the fleet the phones enroll into, next to
the PIN profile:

```json
{
  "shortSupportMessage": {
    "defaultMessage": "Your apps are blocked until you set a screen lock PIN. Open your notifications and tap \"Unblock your apps\", or set a PIN in Settings."
  }
}
```

When an end user taps a blocked app, Android shows this text instead of "Contact your organisation's IT
administrator". In our tests it cut the time from blocked apps to a PIN from about 4 minutes to about 30 seconds to a minute. Keep it under 200
characters, and add `localizedMessages` for other languages.

**2. Unblocking is near instant.** Apps opened about 3 seconds after the PIN was set in each of our runs. The phone
lifts the block itself; it doesn't wait on Fleet.

**Your question about a PIN in the default policy:** Fleet doesn't let admins change the policy phones enroll with
today. Every enrollment, personal and company-owned, uses the same one, so a PIN there would also hit personal
devices. That's the change we're scoping for company-owned phones only:
https://github.com/fleetdm/fleet/issues/57461. We haven't been able to test it, because it needs a Fleet change. In
the one run where our PIN settings arrived early, Android asked for the PIN during setup, which is what we expect
from that change.

**To match what your team reproduced:** could you share the device models and Android versions, and a photo of the
"blocked by your work policy" screen if it shows up again? We tested on a Samsung with Android 16 and haven't seen a
block during setup yet.
