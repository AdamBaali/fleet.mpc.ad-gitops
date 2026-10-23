# fleet.mpc.ad GitOps

GitOps configuration for the lab Fleet at `https://fleet.mpc.ad`, plus the testing that goes with it.
A push to `main` applies the configuration to Fleet (`.github/workflows/workflow.yml`).


## Layout

| Path | What it is |
| --- | --- |
| `default.yml` | Global settings: org settings, certificate authorities, global policies and reports |
| `fleets/<name>.yml` | One file per fleet: its policies, reports, software, settings and enroll secret |
| `fleets/<name>/` | That fleet's own documentation and helper files (not read by GitOps) |
| `lib/<platform>/...` | Shared building blocks the fleet files point to: policies, reports, scripts, profiles, software |
| `testing/<project>/` | One folder per test project: plan, results, generated `EVIDENCE.md`, raw evidence, lab setup |
| `testing/<project>/private/` | Internal notes for that project (customer names, Slack and ticket links). Git ignores it |
| `testing/_framework/` | The reusable testing method: templates, helpers, the evidence index builder |
| `extensions/` | The Windows YellowKey osquery extension source |
| `.github/workflows/` | `workflow.yml` applies the configuration. `duo-sync*.yml` sync Fleet hosts to Duo for the Ping Duo Lab |


## Fleets

| Fleet | Purpose | Config | Docs |
| --- | --- | --- | --- |
| Ping Duo Lab | Test the PingFederate and Duo guides (fleetdm/fleet#54654) | `fleets/ping-duo-lab.yml` | `fleets/ping-duo-lab/`, `testing/conditional-access-54654/` |
| 🐧 Flock to Fedora | Linux atomic, OpenClaw and Windows YellowKey assets | `fleets/flock-to-fedora.yml` | `fleets/flock-to-fedora/` |
| Linux LUKS Lab | Test Linux disk encryption behavior (fleetdm/fleet#54871) | `fleets/linux-luks-lab.yml` | `testing/linux-luks-54871/` |
| iOS Google Lab | Test the Google conditional access guide for iPhones (fleetdm/fleet#55107) | `fleets/ios-google-lab.yml` | `testing/google-ca-55107/` |
| Windows BitLocker Lab | Test BitLocker PIN with a custom disk encryption profile (fleetdm/fleet#42318) | `fleets/windows-bitlocker-lab.yml` | `fleets/windows-bitlocker-lab/`, `testing/bitlocker-pin-42318/` |
| Power Nap Lab | Test installs and scripts on a sleeping Mac laptop (fleetdm/fleet#46924) | `fleets/power-nap-lab.yml` | `fleets/power-nap-lab/`, `testing/power-nap-46924/` |
| ServiceNow ITAM Lab | Test software fields for a ServiceNow ITAM export (fleetdm/fleet#38864) | `fleets/servicenow-itam-lab.yml` | `fleets/servicenow-itam-lab/`, `testing/servicenow-itam-38864/` |


## Test projects without a fleet

| Project | Purpose |
| --- | --- |
| `testing/app-suffix-34088/` | Diagnosis and tested SQL cleanup for macOS software names ending in ".app" (fleetdm/fleet#34088). Runs against Fleet's test database, not the lab Fleet |
| `testing/byod-ios-okta/` | Research and a checked draft reply on personal phones (iPhone User Enrollment, Android work profile) with Fleet, Auth0 now and Okta later. Lab tests still to run |


## Adding a fleet or a test

1. Fleet: add `fleets/<name>.yml` (the `name:` must be unique), put shared files under `lib/`, and add
   `fleets/<name>/README.md` with the purpose, owner, and issue link.
2. Test project: copy `testing/_framework/templates/` into `testing/<project>/`, run the tests with
   `testing/_framework/bin/ev.sh`, and build `EVIDENCE.md` with `build-evidence-index.py`. See `testing/_framework/README.md`.
3. Pushes that only touch `testing/`, `fleets/<name>/`, or markdown don't start a live apply.


## Rules

This repository is public. Everything committed here can be read by anyone.

- Secrets live in GitHub repository secrets and are referenced as `$FLEET_*` variables. Nothing secret is committed.
- No customer or person names in committed files. Refer to a customer by its GitHub label (for example `customer-ufa`) and to requests by public issue numbers. Internal notes, Slack, ticket and call links go in `testing/<project>/private/`, which git ignores.
- PR titles, PR descriptions, and commit messages don't cite fleetdm/fleet issues: no `fleetdm/fleet#123` and no issue links. Each mention adds a permanent "mentioned this" link on the upstream issue, and GitHub keeps it even after the text is edited. Files in the repo can cite issues.
- Work on a branch and merge through a pull request. `main` applies to the lab Fleet.
- Docs and drafts follow Fleet's writing guide (`handbook/company/writing.md` in fleetdm/fleet). The short version is in `CLAUDE.md`.


## Lab CA retired

The lab CA for fleetdm/fleet#54654 (`LAB_CA`, step-ca behind a Cloudflare tunnel) is removed now that its testing is finished. Applies no longer
need Docker or the tunnel running. The repository secrets `FLEET_LAB_CA_SCEP_CHALLENGE` and `FLEET_SECRET_LAB_CA_THUMBPRINT` are unused.
