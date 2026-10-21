<!-- Comment for fleetdm/fleet#52314. Not posted. Adam posts it and adds the customer-ufa label. -->
Adding `customer-ufa`. They upgraded through 4.76.0 and reported "several software IDs for the same version and OS" for TeamViewer and similar software. That fits this issue, and CHECK 7 below will confirm it on their data: rows created before 4.76.0 keep the name-first checksum, and the next host to report the same software inserts a second row.

Reproduced on `main` (e1cf388cca), 4.93.1 and 4.90.3 in Fleet's test database: a `software` row with the name-first checksum, linked to one host, gets a twin as soon as a second host reports the same app through `UpdateHostSoftware`. Test: [testing/app-suffix-34088, C3](https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/testing/app-suffix-34088/RESULTS.md).

On scope: this customer has a large `software` table. A read-only sizing query for their instance, grouped by source (the same grouping as the query above), is CHECK 7 in [1_diagnose.sql](https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/testing/app-suffix-34088/sql/1_diagnose.sql). I'll add their numbers here once they run it.

A related ask: macOS apps with a bundle ID are not affected (migration `20251015103505` recomputed them in 4.75.0), so the unscoped repair could skip `source = 'apps' AND bundle_identifier <> ''` to cut cost.
