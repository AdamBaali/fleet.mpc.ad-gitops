**Update: macOS and Linux done, Windows is the only thing outstanding**

Since my last post:

- **Renewal:** Fleet renewed the lab certificate on the Mac twice with no one at the machine.
- **macOS:** Safari, Chrome and Firefox sign in with the certificate. A failing critical policy denies sign-in and recovers within 1 to 3 minutes. Duo (through Duo Desktop) trusts the Mac, blocks it when it's not in the list, and trusts it again after the next sync.
- **Duo sync:** every 5 minutes for 4 days, 723 cycles, 0 Duo errors or rate limits. Four runs failed to reach Fleet (connection reset, two timeouts, one DNS failure) and the next run recovered each time.
- **Duo Desktop on Linux:** Fleet installs it through a policy, like macOS and Windows (about 2 minutes from the failed policy to a running service).
- **Linux certificates:** Fleet's EST path works. Fleet requested a certificate from an EST server, and the host signed in to PingFederate with it (tested with a small test EST server, since step-ca doesn't support EST).
- **Evidence:** pictures for every macOS and Linux test, plus the Fleet, Duo and PingFederate console pages. [Start here](https://github.com/AdamBaali/fleet.mpc.ad-gitops/tree/main/testing/conditional-access-54654).

**Guide fixes**
- **Ping Step 6:** the policy contract needs only `subject`, mapped to the adapter.
- **Ping, macOS:** each browser asks for the keychain password once. The user selects **Always Allow**. I can tighten the wording later.
- **Duo sync:** the guide now uses a daily sync, as Duo recommends. GitHub's scheduler can't hold a 5-minute schedule: in 13 hours a `*/5` schedule started 2 runs, and a 30-minute one started none. A run started by hand works as intended. A host enrolled after the daily run can wait up to a day for its first sign-in unless someone runs the workflow by hand.

**Not tested:** sign-in through a SAML or OIDC app (I used an OAuth client, which runs the same authentication policy).

**Windows (Windows 11 Arm VM):** certificate profile, MachineGuid report, Duo export and sync, Edge sign-in with the certificate auto-selected, a failing critical policy denying sign-in and recovery after the fix all pass. Duo says Duo Desktop for Windows is Intel-only; the x64 installer installs and runs under Windows' x64 emulation (7.22.0, both local servers start, TPM present), so I treat that as an experiment, not support. The Duo sign-in (D-5) passes under emulation when the VM has no TPM: Duo Admin lists the device as Trusted Endpoint: Yes. With a virtual TPM present Duo Desktop logs `error loading dakey` and Duo does not trust the device; I didn't find the cause inside that TPM path (UTM's TPM or Duo under emulation). That is an emulation result, so the guide shouldn't claim Windows on Arm. Still to do on Windows: D-8, `report_cap` (needs two Windows hosts) and renewal.

**New guide fix from Windows:** the root CA profile (`RootCATrustedCertificates/Root/<name>/EncodedCertificate`) failed with status 500 with a free-text node name and worked once the node was named by the certificate's SHA-1 thumbprint. Chrome and Edge on Windows need the `AutoSelectCertificateForUrls` registry policy; the guide doesn't say how to deploy it.

Next: a draft PR with the guide fixes. It stays in draft until Windows is done.
