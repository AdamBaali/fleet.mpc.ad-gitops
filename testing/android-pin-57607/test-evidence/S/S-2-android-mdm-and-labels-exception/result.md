# S-2: android mdm and labels exception

- **Started:** 2026-11-05T09:04:36Z
- **Objective:** Android MDM is on and GitOps can manage labels
- **Expected:** android_enabled_and_configured true, labels exception false

## Steps and evidence
- `01-config.txt`: `tools/setup-check.sh config`

## Result: PASS

Android MDM on, labels exception off, so android-pin-label.yml stays in GitOps.

_Finished 2026-11-05T09:04:36Z_
