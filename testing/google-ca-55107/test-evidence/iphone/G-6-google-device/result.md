# G-6: iPhone appears in Google, blocked before the first sync

- **Date:** 2026-10-09
- **Objective:** Sign in to a Google app so basic mobile management adds the device
- **Expected:** Device in Google; access denied because Fleet hasn't marked it yet

## Steps and evidence
- `00`: before sign-in, Google `devices.list` and `deviceUsers.list` return 0.
- Sign in to the **Drive** app as the managed test user (Gmail isn't activated on the lab domain). Google shows "Device info syncing for secure app access" (`02`), then **"Your organisation isn't allowing access"** (`03`).
- `01`: Google created the device: `deviceType IOS`, `model "iPhone 15 Pro Max"` (marketing name, not `iPhone16,2`), `ownerType BYOD`, device user `APPROVED`.
- The script's `^ipad` test on `model` maps it to `iphone`, matching Fleet's `platform: ios`.

## Result: PASS
