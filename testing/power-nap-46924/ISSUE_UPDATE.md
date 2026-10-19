**Update: not started on hardware yet**

Since my last post:
- **Desk:** fleetd holds no sleep assertion during downloads, installs or scripts (only around swiftDialog in setup experience), and falls back from the presigned URL to Fleet straight away with no retry or resume. This matches the mechanism robbiet480 described.
- **Evidence:** [start here](https://github.com/AdamBaali/fleet.mpc.ad-gitops/tree/main/testing/power-nap-46924)

**Not tested:** everything on hardware.

Next: run the installs and a script with the lid closed on battery, and post fleetd and `pmset -g log` output for the same window.
