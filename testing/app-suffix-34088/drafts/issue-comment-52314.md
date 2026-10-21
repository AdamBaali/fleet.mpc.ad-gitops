<!-- Comment for fleetdm/fleet#52314. Not posted. Adam posts it and adds the customer-ufa label. -->
Adding `customer-ufa`. They upgraded from 4.7x to 4.90.3 and reported several software IDs for the same version and OS (TeamViewer and similar). That may be this issue. I'll ask them to run the read-only query in the description after their 4.93 upgrade, and I'll add the results here.

Two details from the release tags that affect scope:
- The checksum change shipped in 4.75.0, not 4.76.0. In `fleet-v4.74.0`, `ComputeRawChecksum` put the name first for software that isn't a macOS app, and left the name out for macOS apps. In `fleet-v4.75.0`, the name is last for all software.
- Migration `20251015103505` (4.75.0) recomputed checksums only for macOS apps with a bundle ID. macOS apps without a bundle ID still have a checksum without the name, so they can duplicate too. A wider repair could skip `source = 'apps' AND bundle_identifier <> ''`.
