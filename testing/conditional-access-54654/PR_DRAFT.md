# Draft PR text (not opened, nothing posted)

**Where it would go:** a PR into `ping-managed-hosts-guide` (the head branch of #54346), so Noah can merge it into his PR. Branch: `adam/ping-duo-fixes-v2` (3 commits on top of #54346's head). Open it as a draft.

## Title

Fixes to the PingFederate and Duo conditional access guides from lab testing

## Description

Related to #54654 and #54346.

I followed the PingFederate and Duo guides in a lab and fixed what didn't work. This PR changes only text and one script. Each change below was tested, except where noted.

### PingFederate guide
- Step 6: use the variable names the authentication policy accepts. `${hostUUID}` and `${fleetHostID}` don't resolve in a lookup path. Use `${ad.<adapter ID>.CN}` and `${ds.<source ID>.<attribute>}`.
- Remove the claim that `fleetHostID` must be mapped. Sign-in works without it.
- Client Authentication Port is required on PingFederate 13.1.3.
- macOS: add `AllowAllAppsAccess` to the SCEP payload. Each browser still asks for the keychain password once. The user selects **Always Allow**. If they refuse, sign-in fails with "Authentication failed". Firefox must be restarted after a wrong answer.
- Browser auto-select: use the host and port that ask for the certificate (9032), not the sign-in port. On Windows, set the policy in the registry. Tested with Edge. Chrome uses the same mechanism and wasn't tested.
- Windows: the Okta Verify example sets `SubjectName` to the serial number. Change it to `CN=$FLEET_VAR_HOST_UUID,OU=$FLEET_VAR_CERTIFICATE_RENEWAL_ID`.
- Windows: if the host doesn't trust your CA, deploy a root certificate profile. Name the `RootCATrustedCertificates` node with the certificate's SHA-1 thumbprint. A made-up name failed with status 500 in testing. Tested with one CA.

### Duo guide
- Keep the Duo keys as GitHub secrets and use a keyless version of Duo's script, so the workflow can run.
- Note that GitHub's scheduler is best effort. A 5-minute schedule started 2 runs in 11 hours. For a steady 5 minutes, use cron or a systemd timer. A run every 5 minutes also uses about 8,600 minutes a month.
- Add a dry run and a note about the macOS local network prompt.
- List the API endpoints each API-only user needs. Tested with throwaway users: both lists are enough, and other endpoints return 403.
- Prerequisites: Linux needs x86-64 hosts, and Windows needs Intel hosts. Duo lists both as the only supported hardware. Duo Desktop did run on Arm VMs under emulation in testing (Linux and Windows 11), and Duo trusted the hosts, so the guide says that and that it isn't supported.

### Script
- `import-certificate-to-browsers.sh`: fixes found on Ubuntu 24.04 (deb Firefox, snap Chromium, snap Firefox, Chrome).

## What I tested
Lab: Fleet 4.93.0 Premium, step-ca (SCEP), PingFederate 13.1.3, a Duo trial, macOS, Ubuntu 24.04 (Arm VM, Duo Desktop under emulation), Windows 11 (Arm VM).

- macOS and Linux: certificates, Safari, Chrome, Firefox sign-in, a failing critical policy denies sign-in and recovers, Duo trusts the host and blocks it when it isn't in the list.
- Duo sync: every 5 minutes for 4 days, 723 cycles, 0 Duo errors. Four runs couldn't reach Fleet and the next run recovered each time.
- Windows: certificate profile, MachineGuid report, export and sync, Edge sign-in with the certificate selected automatically, critical policy denial and recovery. Duo trusted the host when the VM had no TPM. With the VM's virtual TPM, Duo Desktop couldn't load its key and Duo didn't trust the host. This is an emulation result, so I haven't claimed Windows on Arm.

## Not tested
- Sign-in through a SAML or OIDC app (I used an OAuth client, which runs the same authentication policy).
- A real enterprise CA, PingFederate clustering, and a large fleet (`report_cap`).
- Windows: Duo on Intel hardware, blocking a host removed from Duo's list, certificate renewal, Chrome.
- Fleet's EST path for Linux (tested with a small test EST server only).

## Question for @noahtalerman
Should the guide say a brand-new host can sign in before its first policy run? It does in testing (P-13).

Evidence and scripts: https://github.com/AdamBaali/fleet.mpc.ad-gitops/tree/main/testing/conditional-access-54654

## Checklist
- [ ] Changes file not needed (guides and a script only)
- [ ] Manual QA: done in the lab above
