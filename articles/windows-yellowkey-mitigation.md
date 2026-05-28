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

The `windows-yellowkey-extension` policy checks `osquery_registry` for the `windows_yellowkey` table and passes when it is loaded. Failing hosts run `install-yellowkey-extension.ps1`. The script downloads the architecture-matching binary, verifies its SHA-256, places it under `C:\Program Files\osquery\extensions\`, adds the path to `C:\Program Files\osquery\extensions.load`, hardens the ACLs, and restarts the `Fleet osquery` service. osqueryd autoloads the extension on the next start.

The script writes to osquery's compiled-in default autoload path on Windows, not to orbit's directory. `<orbit-root-dir>\extensions.load` is owned by orbit's `ExtensionRunner`, which keeps it empty unless Fleet has TUF-managed extensions configured, and Fleet's API rejects setting `extensions_autoload` in agent options. Because orbit only passes `--extensions_autoload` to osqueryd when its own loader file is non-empty, osqueryd falls back to its compiled default. That default is `C:\Program Files\osquery\extensions.load` per [osquery's `default_paths.h`](https://github.com/osquery/osquery/blob/master/osquery/utils/config/default_paths.h), which is where the script writes. This is the Windows twin of the pattern that writes to `/etc/osquery/extensions.load` on Linux and `/var/osquery/extensions.load` on macOS. No agent options, no TUF update server, no scheduled task.

The binaries are committed under `extensions/windows_yellowkey/`. No release tag to cut. Rebuild with `make build` and commit when the source changes; bump `$ExtensionVersion` and the matching `Sha` values in the installer in the same commit.

<!-- TODO(allen-repo): once the extension is published in allenhouchins/fleet-extensions, replace the "committed under extensions/windows_yellowkey/" wording with a link to https://github.com/allenhouchins/fleet-extensions/tree/main/windows_yellowkey, and point $BaseUrl in the installer at Allen's raw URL. Allen's CI builds the binaries on push to that directory. -->

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
1. The policy runs on the next interval; failing hosts run the installer (default 60 seconds for the first check).
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

Check the host in an elevated PowerShell:

```
# 1. The loader file at osquery's compiled default path lists the binary
Get-Content 'C:\Program Files\osquery\extensions.load'

# 2. The binary is in place (~5.6 MB amd64, ~5.2 MB arm64)
Get-Item 'C:\Program Files\osquery\extensions\windows_yellowkey.ext.exe' |
  Select-Object Length, LastWriteTime

# 3. The script's last run is recorded under Fleet > Hosts > [host] > Activity > Scripts
```

If `extensions.load` is missing or does not list the binary, the script did not finish; read its stdout under Activity > Scripts. If both look right but the table is still missing, search `C:\Windows\System32\config\systemprofile\AppData\Local\FleetDM\Orbit\Logs\orbit-osquery.log` for `unsafe permissions` or `Timed out waiting for extension`. Re-running the installer re-asserts the ACLs and the loader entry.

Operational notes
-----------------

- Inspect one host with `SELECT * FROM windows_yellowkey`. If the extension will not load, `reagentc /info` and `Get-BitLockerVolume` give the same signals without osquery.
- `reagentc /disable` also removes push-button reset, in-WinRE BitLocker recovery, System Restore from boot, and Recovery Drive restore. Re-enable with `reagentc /enable` before you need them.
- Move high-risk hosts to TPM + PIN where the threat model includes physical access. It blocks the public PoC and raises attacker cost on the withheld variant.
