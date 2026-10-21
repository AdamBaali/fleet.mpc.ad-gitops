<!-- Comment for fleetdm/fleet#52314. Not posted. Adam posts it and adds the customer-ufa label. -->
Adding `customer-ufa`. They upgraded from 4.7x to 4.90.3 and reported several software IDs for the same version and OS (TeamViewer and similar). That may be this issue. We're asking them to run a read-only check to confirm.

Two details from the release tags that affect scope:
- The checksum change shipped in **4.75.0**, not 4.76.0. In `fleet-v4.74.0`, `ComputeRawChecksum` put the name first for non-app software and left the name out for macOS apps. `fleet-v4.75.0` puts it last for everything.
- Migration `20251015103505` (4.75.0) recomputed macOS apps with a bundle ID only. macOS apps without a bundle ID still carry the no-name checksum, so they can duplicate too. An unscoped repair could skip `source = 'apps' AND bundle_identifier <> ''`.

Reproduced on `main` (e1cf388cca), 4.93.1 and 4.90.3 in Fleet's test database: a macOS app row without a bundle ID and with the pre-4.75 checksum, linked to one host, gets a twin as soon as a second host reports the same app through `UpdateHostSoftware`. Test C3: https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/testing/app-suffix-34088/RESULTS.md

Sizing query for their instance, grouped by source with the same grouping as the query above: CHECK 7 in https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/testing/app-suffix-34088/sql/1_diagnose.sql. I'll add their numbers here.
