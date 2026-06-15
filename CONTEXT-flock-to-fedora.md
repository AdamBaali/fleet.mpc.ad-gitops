# Flock to Fedora: atomic fleet management and OpenClaw detection

Context for Claude Code working on the Linux/atomic and OpenClaw assets in
this repo. Read this first. The YellowKey pattern has its own context in
`CONTEXT.md`; match the style rules at the end of that file.

## What this is

The companion GitOps assets for the "From Compliance to Containers" talk at
Flock to Fedora 2026 (Adam Baali, Fleet; Jonathan Billings, Red Hat). The
talk proves NIST controls with osquery on Fedora, then shows how to keep
visibility on atomic hosts (Silverblue, Bluefin, CoreOS) where `/usr` is
read-only and `rpm -qa` tells only part of the truth. The OpenClaw section
demos detecting an AI-agent malware family across the same fleet.

The demo fleet is `fleets/flock-to-fedora.yml` (renamed from
`workstations.yml`). It is cross-platform: it still carries the Windows
YellowKey policy and the macOS nanoca profiles and munki software, and now
adds the Linux and OpenClaw assets below.

## What's in this repo

```
lib/linux/
├── policies/
│   ├── rpm-ostree-extension.policies.yml   # keeps the rpm_ostree extension loaded; run_script installs on fail
│   ├── nist-sc-28-luks.policies.yml        # root fs is LUKS-encrypted (SC-28)
│   ├── nist-ia-5-ssh-keys.policies.yml     # no aged / orphaned / weak SSH keys (IA-5(2))
│   └── openclaw-detection.policies.yml     # scored presence + systemd persistence
├── reports/
│   ├── rpm-ostree-deployments.reports.yml  # booted/staged/rollback inventory (the three truths)
│   ├── nist-ia-5-ssh-keys.reports.yml      # the offending keys, for the auditor
│   ├── cve-scanning-baseline.reports.yml   # OS identity the vuln engine maps to RHEL OVAL
│   └── openclaw-detection.reports.yml      # investigation (snapshot) + threat hunting (differential)
└── scripts/
    └── install-rpm-ostree-extension.sh     # downloads + loads the extension; orbit restart

lib/macos/
├── policies/openclaw-detection.policies.yml  # scored presence + launchd persistence
└── reports/openclaw-detection.reports.yml    # adds Gatekeeper-bypass and AMOS C2 hunts
```

The rpm_ostree osquery extension (Go source, binaries, CI) lives upstream in
[`AdamBaali/fleet-extensions/rpm_ostree`](https://github.com/AdamBaali/fleet-extensions/tree/main/rpm_ostree).
This repo holds the policy, the report, and the install script that pulls it.

## The atomic extension (rpm_ostree)

osquery 5.23.0 ships no `rpm_ostree_deployments` table, so on Silverblue and
Bluefin Fleet sees only the booted commit through `rpm_packages` and is
blind to staged and rollback deployments. The extension wraps
`rpm-ostree status --json` and returns one row per deployment.

Deployment mirrors the YellowKey pattern, adapted for Linux and for atomic
hosts:

- The `rpm-ostree-extension` policy checks `osquery_registry` for the
  `rpm_ostree_deployments` table plugin (`SELECT 1 FROM osquery_registry
  WHERE registry = 'table' AND name = 'rpm_ostree_deployments' AND active =
  1`). One row when loaded (pass), zero rows when not (fail). Querying the
  table directly would error when the extension is absent, which Fleet shows
  as neither pass nor fail and would not trigger the installer.
- Failing hosts run `install-rpm-ostree-extension.sh`. It downloads the
  architecture-matching `.ext` from the upstream `main` branch over HTTPS,
  checks the ELF magic bytes, installs it 0700 root:root under
  `/var/lib/fleetd/extensions/`, adds `--extension=<path>` to
  `/var/lib/fleetd/osquery.flags` idempotently, and restarts orbit.
- `/var` is deliberate: on atomic hosts it is the only persistent writable
  mount, and orbit keeps its root there. The binary is statically linked, so
  it carries no dependency on the frozen `/usr`.

The upstream repo must stay public for the unauthenticated download to work,
the same constraint the Windows installer has against Allen's repo.

Match the report's column names to the extension exactly. They are defined
in `RPMOstreeColumns()` in the upstream `main.go`; if the columns change
upstream, update `rpm-ostree-deployments.reports.yml` to match.

## NIST controls (from the talk demos)

- SC-28: `nist-sc-28-luks.policies.yml`. Passes when the root device is a
  LUKS device-mapper target (`/dev/dm-%`) with `encrypted = 1`.
- IA-5(2): `nist-ia-5-ssh-keys.policies.yml`, three policies. Each passes
  when its offending set is empty (aged > 1yr, orphaned uid, DSA). The
  matching reports list the offending keys for evidence.
- CVE scanning: `cve-scanning-baseline.reports.yml` surfaces `os_version`,
  the input Fleet maps to RHEL OVAL (no Fedora-native OVAL exists) plus NVD
  CPE for the long tail. The matching and the webhook on new findings run
  server-side; there is no on-host CVE query.

## OpenClaw detection

Source of truth for the indicators:
https://fleetdm.com/guides/mitigation-assets-and-detection-patterns-for-ai-agents-like-openclaw

Detection policies invert the usual sense: a clean host returns a row and
**passes**, a host showing the threat returns zero rows and **fails**. Wire
a failing-policy webhook (Settings > Integrations) to alert on a fail, which
is the response path the guide describes.

- The scored "AI agent not detected" policy sums four independent
  indicators (process, gateway port 18789/18793, persistence unit, config
  file) and fails at three or more. Any one alone keeps the host passing,
  which is the guide's threshold for avoiding false positives.
- Persistence is a separate single-indicator policy per platform
  (`openclaw-gateway` systemd unit on Linux, `ai.openclaw.gateway` and
  siblings in launchd on macOS), since those names are unambiguous.
- No `run_script` is attached to any OpenClaw policy. Killing a live agent
  or deleting its files is a response decision, and the guide's hardening
  path is `openclaw security audit --deep --fix`, run deliberately.

Reports split by intent: investigation queries use `snapshot` logging
(current state, daily); threat-hunting queries use `differential` logging at
a shorter interval, since the behaviour they catch (shell spawning,
pipe-to-shell, Gatekeeper bypass, C2 connections) is transient. Linux
reports use `/home/%` and `/root` paths; macOS reports use `/Users/%` and
add the Gatekeeper-bypass (`xattr -c`) and AMOS C2 hunts.

## Validate before shipping

```bash
# Only Fleet tables and supported columns. Tables used here:
#   processes, listening_ports, file, users, authorized_keys, disk_encryption,
#   os_version, kernel_info, osquery_registry, process_open_sockets,
#   systemd_units (linux), launchd (darwin), rpm_ostree_deployments (extension)
# Schema: https://github.com/fleetdm/fleet/tree/main/schema

# Dry run the whole repo (what CI does):
FLEET_DRY_RUN_ONLY=true ./gitops.sh
```

Detection policies must keep the pass = clean inversion: the query returns a
row for a healthy host and zero rows for a flagged one. Reversing it would
alert on every clean host.
