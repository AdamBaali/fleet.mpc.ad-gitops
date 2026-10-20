**Update: reproduced on a MacBook Air (Fleet download, no presigned URL)**

Lab: MacBook Air (M4), macOS 27.0.1, fleetd 1.61.0 (orbit 1.61.0, osquery 5.24.0), Power Nap on, policy automation installs Google Chrome. Downloads come from the Fleet server only.

- **Control, lid open:** Chrome installs from the policy automation (C-1).
- **Lid closed, battery (PN-1):** reproduced. DarkWakes last 2 to 10 s, about every 16 minutes. fleetd starts the download in a 2 s DarkWake (14:06:16 local). At the next DarkWake 17 minutes later (14:23:26) fleetd logs `failed to download software installer ... copying from http stream to file: read tcp`, and Fleet shows "Software installer download failed."
- **What happens next (PN-6):** Fleet queues one retry at the failure. It did not start in the two DarkWakes over the next 37 minutes. It ran 50 s after the lid opened and installed.
- **Side finding:** an orbit restart in the middle of a download (here about 90 s after MDM enrollment) drops the download with no error line. Fleet re-sends the install.

orbit and `pmset -g log` lines for the same window are in [PN-1](https://github.com/AdamBaali/fleet.mpc.ad-gitops/tree/main/testing/power-nap-46924/test-evidence/mac/PN-1-large-install-lid-closed-battery). All results: [EVIDENCE.md](https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/testing/power-nap-46924/EVIDENCE.md).

**Not tested yet:** a small install (PN-2, running), a script run (PN-3), lid closed on power (PN-4), Power Nap off (PN-5), a `caffeinate` wrapper (PN-7), presigned URLs.
