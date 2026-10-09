# Screenshots proposed for the guide

Cleaned copies of test evidence, for the guide in [#55107](https://github.com/fleetdm/fleet/pull/55107). Metadata (EXIF, XMP) is
removed. `../../scripts/guide-images.py` builds them from `../../test-evidence/`, so every edit is listed in code.

| Image | Guide spot | Alt text | Source and edits |
|---|---|---|---|
| [01](01-google-device-managed-by-fleet.png) | Step 3, "To check a sync" | Google Admin console, Third-party services for an iPhone: fleet (custom), Managed, Compliant, with the serial number under Asset tags | [E-2b](../../test-evidence/iphone/E-2b-idp-path-run-through/02-console-managed-serial-asset-tag-masked.png). The black mask over the serial is replaced with `XXXXXXXXXX` in the console font. Cropped at the bottom. |
| [02](02-google-device-unmanaged.png) | Step 3, next to 01 (optional) | The same panel after Fleet stops counting the iPhone: Unmanaged, Non-compliant | [E-2](../../test-evidence/iphone/E-2-fleet-stops-counting-the-iphone/02-console-fleet-custom-unmanaged.png). A half-typed search is cleared. Cropped at the bottom. |
| [03](03-access-level-condition.png) | Step 4, item 2 | Create access level, Advanced tab, with the condition in the CEL editor | [C-1e](../../test-evidence/iphone/C-1e-keyless-exists-condition/01-condition-saved.png). Cropped to the Context conditions card, which leaves out the old "partner ID fleet" description. The editor is shortened. |
| [04](04-iphone-blocked.png) | Step 5 | iPhone, Google: "Your organisation isn't allowing access" | [E-2b](../../test-evidence/iphone/E-2b-idp-path-run-through/04-r3-blocked-live.png). No edits. |
| [05](05-iphone-sign-in-again.png) | Step 5, the line about signing in again | iPhone, Google: "Please sign in again" | [E-2b](../../test-evidence/iphone/E-2b-idp-path-run-through/05-r4-please-sign-in-again.png). A "Google apps" tooltip is removed, using the header from 04. |

The phone and the console are set to UK English, so Google shows "organisation" and dates as day/month. US readers see US
spelling.

Still missing: the Step 4 assignment dialog with **Apply to Google desktop and mobile apps** selected and **Active**, not
**Monitor**. That setting is the easiest to get wrong, and the evidence has no capture of it.
