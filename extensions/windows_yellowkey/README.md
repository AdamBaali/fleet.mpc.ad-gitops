# YellowKey osquery extension (CVE-2026-45585)

A native osquery extension that gives every Windows host one row of YellowKey verdict. The `windows-yellowkey` report queries it directly. No snapshot file, no freshness gate, every query is live.

Pattern adapted from [`allenhouchins/fleet-extensions/secureboot_cert_update`](https://github.com/allenhouchins/fleet-extensions/tree/main/secureboot_cert_update).

## Table: `windows_yellowkey`

| Column | Type | Meaning |
|---|---|---|
| `state` | text | The verdict (see below) |
| `state_reason` | text | One-line explanation |
| `needs_action` | int | `1` when `state = exposed` |
| `winre_enabled` | text | `Enabled`, `Disabled`, or `unknown` |
| `tpm_only` | int | `1` when a volume uses TPM without a PIN (what the PoC targets) |
| `mitigated` | int | `1` when the `BootExecMitigated` marker is set |

`state` is derived on the host, first match wins:

1. `not_affected`: Windows 10 or unrecognised SKU
2. `mitigated`: `BootExecMitigated` marker set
3. `mitigated_winre_off`: WinRE disabled
4. `bitlocker_off`: no protected BitLocker volume
5. `exposed`: affected OS + BitLocker on + no mitigation

It reads three things osquery can't get natively: WinRE state (`reagentc /info`), BitLocker key protector types (`Get-BitLockerVolume`), and the Fleet success marker (`HKLM\Software\Fleet\YellowKey\BootExecMitigated`).

## Build

Requires Go 1.21+. Cross-compiles from any platform:

```
make deps
make build
```

Produces `windows_yellowkey-amd64.exe` and `windows_yellowkey-arm64.exe`.

## Deploy

`install-yellowkey-extension.ps1` (attached to the `windows-yellowkey-extension` policy) reads the host architecture, downloads the matching binary from the repo's raw URL on `main`, verifies its SHA-256, places it under `C:\Program Files\Orbit\extensions\`, adds the path to `extensions.load`, hardens the ACLs, and restarts the `Fleet osquery` service. osquery autoloads the extension on the next start.

For autoload to take effect on Windows, the team's agent options enable extensions and point at the loader file. fleetd regenerates `osquery.flags` from agent options on every config refresh, so these flags go through GitOps, not by editing `osquery.flags`:

```yaml
agent_options:
  overrides:
    platforms:
      windows:
        command_line_flags:
          disable_extensions: false
          extensions_autoload: 'C:\Program Files\Orbit\extensions.load'
          extensions_timeout: 10
          extensions_interval: 3
```

These are osqueryd command-line flags, not config options. Fleet rejects them under `options` (`"disable_extensions" should be part of the "command_line_flags" object`).

The binary, the loader, and the extensions directory are hardened to owner Administrators, no inherited ACEs, full control for Administrators and SYSTEM, read+execute for Users (.NET `FileSystemAccessRule` with well-known SIDs so it works on non-English Windows). `extensions.load` is written ASCII with no BOM; a UTF-16 or BOMed loader makes osquery skip the file and load zero extensions silently.

To set the agent options through the Fleet UI instead of GitOps, go to **Settings > Organization settings > Agent options** for an "All teams" change, or **Settings > Teams > [team] > Agent options** for a single team. The YAML layout is documented at [YAML files](https://fleetdm.com/docs/configuration/yaml-files), and the full options list at [agent configuration](https://fleetdm.com/docs/configuration/agent-configuration).

The binaries are committed in this directory, so no release is needed. To update: rebuild with `make build`, commit the binaries, and bump `$ExtensionVersion` + both `Sha` entries in the installer in the same commit.

Test interactively without deploying (loads only this extension, bypasses the safe-permissions check):

```
'C:\Program Files\Orbit\bin\orbit\orbit.exe' shell -- --extension .\windows_yellowkey-amd64.exe --allow-unsafe
```

## Sample queries

```sql
-- Everything
SELECT * FROM windows_yellowkey;

-- Exposed hosts
SELECT * FROM windows_yellowkey WHERE state = 'exposed';

-- Exposed TPM-only hosts (most at risk)
SELECT * FROM windows_yellowkey WHERE state = 'exposed' AND tpm_only = 1;
```

## Caveats

- The WinRE status words (`Enabled` / `Disabled`) are English-only. On a non-English Windows install the parse falls through to `unknown` and `state` becomes `exposed` (the safe default).
- `mitigated` reflects the `BootExecMitigated` marker, not a live read of the WinRE image. It is not auto-cleared; if Microsoft ships a patch, clear the marker to retire it.
- The interactive test above uses `--allow-unsafe`, which bypasses osquery's permission check. A binary that loads in that shell can still fail to autoload under orbit if its ACL is not hardened. Trust the `SELECT ... FROM windows_yellowkey` query under fleetd, not the local shell.
