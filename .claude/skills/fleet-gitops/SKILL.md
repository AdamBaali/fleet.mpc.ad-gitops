---
name: fleet-gitops
description: Help with Fleet GitOps configuration files including queries, profiles, software, and DDM declarations with validation against upstream references.
allowed-tools: Read, Grep, Glob, Edit, Write, WebFetch, WebSearch
effort: high
---

You are helping with Fleet GitOps configuration files: $ARGUMENTS

This repository keeps GitOps files at the root:

- `default.yml` — global settings, `org_settings`, and `controls` that apply to all hosts ("All fleets").
- `fleets/*.yml` — one file per Fleet fleet (e.g. `fleets/workstations.yml`). Fleet-scoped settings go under `settings:` (not `team_settings:`).
- `lib/` — reusable assets referenced from `default.yml` and fleet files, organized by platform:
  - `lib/all/` — `agent-options/`, `labels/`, `icons/`, shared assets across platforms.
  - `lib/macos/` — `configuration-profiles/` (`.mobileconfig`), `declaration-profiles/` (DDM JSON), `enrollment-profiles/`, `policies/`, `reports/`, `scripts/`, `software/`, `commands/`, `misc/`.
  - `lib/windows/` — `configuration-profiles/` (CSP `.xml`), `policies/`, `reports/`, `scripts/`, `software/`.
  - `lib/linux/` — `policies/`, `reports/`, `scripts/`, `software/`.
  - `lib/ios/`, `lib/ipados/` — `configuration-profiles/`, `declaration-profiles/`.

Reference these assets from `default.yml` or `fleets/*.yml` using relative paths (e.g. `../lib/macos/software/munki.yml`). Apply the following constraints for all work in this session.

## Reports

Reports replace the old top-level `queries:` array. Define each snapshot or scheduled query under a `reports:` array in `default.yml` or `fleets/*.yml`.

- File naming convention: `*.reports.yml` in `lib/<platform>/reports/`.
- Reference via `- path: ../lib/<platform>/reports/<name>.reports.yml` or `- paths: ../lib/<platform>/reports/*.reports.yml`.
- Only use **Fleet tables and supported columns**. Do not reference tables or columns absent from the Fleet schema for the target platform.
- Validate table and column names against the Fleet schema before shipping:
  - https://github.com/fleetdm/fleet/tree/main/schema

## Configuration Profiles

When generating or modifying configuration profiles:

- **First-party Apple payloads** (`.mobileconfig`) — validate payload keys, types, and allowed values against the Apple Device Management reference:
  - https://github.com/apple/device-management/tree/release/mdm/profiles
- **Third-party Apple payloads** (`.mobileconfig`) — validate against the ProfileManifests community reference:
  - https://github.com/ProfileManifests/ProfileManifests
- **Windows CSPs** (`.xml`) — validate CSP paths, formats, and allowed values against Microsoft's MDM protocol reference:
  - https://learn.microsoft.com/en-us/windows/client-management/mdm/
- **Android profiles** (`.json`) — validate keys and values against the Android Management API `enterprises.policies` reference:
  - https://developers.google.com/android/management/reference/rest/v1/enterprises.policies

## Software

- When adding software for macOS or Windows hosts, **always check the Fleet-maintained app catalog first** before using a custom package:
  - https://github.com/fleetdm/fleet/tree/main/ee/maintained-apps
- In GitOps YAML, use the `fleet_maintained_apps` key with the app's `slug` to reference a Fleet-maintained app.
- When remediating a CVE, use Fleet's built-in vulnerability detection to identify affected software, then follow the Software section above to deploy a fix — preferring a Fleet-maintained app update where available, otherwise a custom package.

## Declarative Device Management (DDM)

When generating or modifying DDM declarations:

- Validate declaration types, keys, and values against the Apple DDM reference:
  - https://github.com/apple/device-management/tree/release/declarative/declarations
- Ensure the `Type` identifier matches a supported declaration type from the reference.

## References

- Fleet GitOps documentation: https://fleetdm.com/docs/configuration/yaml-files
- Fleet API documentation: https://fleetdm.com/docs/rest-api/rest-api
