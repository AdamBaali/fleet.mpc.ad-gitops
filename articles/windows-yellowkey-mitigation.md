Detect and mitigate the YellowKey BitLocker bypass with Fleet
=============================================================

[YellowKey (CVE-2026-45585)](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585) is an unpatched BitLocker bypass on Windows 11, Server 2022, and Server 2025. Microsoft shipped a mitigation on May 19, 2026 and no full patch is out yet. This pattern flags exposed hosts in Fleet, reports on them daily, and applies Microsoft's mitigation through a script.

The threat
----------

YellowKey abuses `autofstx.exe` in the Windows Recovery Environment. With brief physical access, an attacker drops a crafted `FsTx` blob on a USB stick or the EFI System Partition and reboots into WinRE. autofstx replays NTFS transaction logs that delete `winpeshl.ini`, so WinRE falls back to `cmd.exe` with the BitLocker volume unlocked. Windows 10 ships a different WinRE component and is not affected.

USB-block GPOs and BIOS USB-boot blocks do not stop it: WinRE ignores the OS USB policy and the attack does not boot from the stick. TPM-only BitLocker is the target. Microsoft's mitigation strips `autofstx.exe` from WinRE's `BootExecute` chain. TPM + PIN blocks the published proof of concept but not the researcher's withheld variant, so treat it as raising attacker cost.

What you'll deploy
------------------

| File | Role |
|---|---|
| `extensions/windows_yellowkey/` | osquery extension; exposes the `windows_yellowkey` table |
| `lib/windows/reports/windows-yellowkey.reports.yml` | Daily per-host report |
| `lib/windows/policies/windows-yellowkey-extension.policies.yml` | Keeps the extension installed |
| `lib/windows/scripts/install-yellowkey-extension.ps1` | Installs the extension |
| `lib/windows/scripts/mitigate-windows-yellowkey.ps1` | Applies Microsoft's mitigation |
| `.github/workflows/build-extensions.yml` | Builds the extension on tag push |

Detect
------

The extension reads OS, WinRE state, BitLocker key protectors, and the `BootExecMitigated` marker on every query, then returns one `state` per host. No snapshot, no freshness gate. A host returns a row once the extension loads; the policy below keeps it loaded.

| state | Meaning |
|---|---|
| `not_affected` | Windows 10 |
| `mitigated` | autofstx stripped, marker set |
| `mitigated_winre_off` | WinRE disabled |
| `bitlocker_off` | no protected BitLocker volume |
| `exposed` | affected OS, BitLocker on, no mitigation |
| `unknown` | unrecognised OS |

The report is one line:

```
SELECT state, state_reason, needs_action, winre_enabled, tpm_only, mitigated FROM windows_yellowkey;
```

Mitigate
--------

`mitigate-windows-yellowkey.ps1` adapts [Microsoft's reference script](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585). It mounts the WinRE image with `reagentc /mountre`, loads the offline SYSTEM hive, strips `autofstx` from every ControlSet's `BootExecute`, unmounts with `/commit`, then runs `reagentc /disable` and `/enable` to re-seal the BitLocker measurement chain.

The script verifies each ControlSet by read-back and writes `HKLM\SOFTWARE\Fleet\YellowKey\BootExecMitigated = 1` only when every one is clean. Exit codes: `0` done, `3` OS not affected, `4` failed. There is no opt-in gate, since Microsoft's strip is safe on every affected host, and no unmitigate path: when Microsoft ships a patch, apply it and clear the marker.

Deploy
------

The `windows-yellowkey-extension` policy checks `osquery_registry` for the `windows_yellowkey` table and passes when it is loaded. Failing hosts run `install-yellowkey-extension.ps1`. The script downloads the architecture-matching binary, verifies its SHA-256, places it under `C:\Program Files\Orbit\extensions\`, adds the path to `extensions.load`, hardens the ACLs, and restarts the `Fleet osquery` service. osquery autoloads the extension on the next start.

For autoload to work on Windows, the team's agent options need to enable extensions and point at the loader file. fleetd regenerates `osquery.flags` from agent options on every config refresh, so the flags go through GitOps, not by editing `osquery.flags` on the host (that change gets overwritten on the next refresh). Add the Windows override to your team:

```yaml
agent_options:
  command_line_flags:
    disable_extensions: false
    extensions_autoload: 'C:\Program Files\Orbit\extensions.load'
    extensions_timeout: 10
    extensions_interval: 3
```

These are osqueryd command-line flags, not config options. Fleet requires `command_line_flags` at the top level of `agent_options` (`"command_line_flags" should be part of the top level object`), so they apply to every platform on the team. `extensions_autoload` points at a Windows path; on macOS and Linux hosts the file does not exist and osquery logs one warning at startup then continues without autoloading anything.

To set this through the Fleet UI instead of GitOps, go to **Settings > Organization settings > Agent options** for an "All teams" change, or open the team under **Settings > Teams** and edit its agent options. Fleet's [agent configuration reference](https://fleetdm.com/docs/configuration/agent-configuration) lists every option, and the team and global YAML layout is documented under [YAML files](https://fleetdm.com/docs/configuration/yaml-files).

The binaries are committed under `extensions/windows_yellowkey/`. No release tag to cut. Rebuild with `make build` and commit when the source changes; bump `$ExtensionVersion` and the matching `Sha` values in the installer in the same commit.

Roll it out
-----------

Pin everything in `fleets/workstations.yml`:

```yaml
policies:
  - path: ../lib/windows/policies/windows-yellowkey-extension.policies.yml
reports:
  - path: ../lib/windows/reports/windows-yellowkey.reports.yml
controls:
  scripts:
    - path: ../lib/windows/scripts/install-yellowkey-extension.ps1
    - path: ../lib/windows/scripts/mitigate-windows-yellowkey.ps1
```

1. Apply: `fleetctl gitops -f fleets/workstations.yml`.
1. Hosts pick up the agent options on the next config refresh (default 60 seconds).
1. The policy runs on the next interval; failing hosts run the installer.
1. Open the report. Run `mitigate-windows-yellowkey.ps1` against `exposed` hosts from Fleet > Controls > Scripts.
1. Re-run the report. Those hosts move to `mitigated`.

Update the extension
--------------------

When the extension changes:

1. Rebuild with `make build` and commit the new binaries under `extensions/windows_yellowkey/`.
1. Bump `$ExtensionVersion` and both `Sha` entries in `install-yellowkey-extension.ps1`.
1. Open a PR. On merge, failing hosts pull the new binary on the next policy run.

If a host stays failing
-----------------------

Check three things on the host, in an elevated PowerShell:

```
# 1. Agent options reached osquery: the extensions flags are present
Get-Content 'C:\Program Files\Orbit\osquery.flags' | Select-String 'extension'

# 2. The loader file lists the binary
Get-Content 'C:\Program Files\Orbit\extensions.load'

# 3. The script's last run is recorded in Fleet > Hosts > [host] > Activity > Scripts
```

If `osquery.flags` is missing the three `extensions_*` lines, the agent options have not propagated yet, or `fleetctl gitops` rejected the override. If `extensions.load` is empty or missing the binary path, the script did not finish; read its stdout under Activity > Scripts. If both look right but the table is still missing, search `C:\Windows\System32\config\systemprofile\AppData\Local\FleetDM\Orbit\Logs\orbit-osquery.log` for `unsafe permissions` or `Timed out waiting for extension`. Re-running the installer re-asserts the ACLs and the loader entry.

Operational notes
-----------------

- Inspect one host with `SELECT * FROM windows_yellowkey`. If the extension will not load, `reagentc /info` and `Get-BitLockerVolume` give the same signals without osquery.
- `reagentc /disable` also removes push-button reset, in-WinRE BitLocker recovery, System Restore from boot, and Recovery Drive restore. Re-enable with `reagentc /enable` before you need them.
- Move high-risk hosts to TPM + PIN where the threat model includes physical access. It blocks the public PoC and raises attacker cost on the withheld variant.
