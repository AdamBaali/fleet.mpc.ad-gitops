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

`install-yellowkey-extension.ps1` (attached to the `windows-yellowkey-extension` policy) reads the host architecture, downloads the matching binary from the repo's raw URL on `main`, hardens the extensions directory ACL so osquery's safe-permission check accepts the binary, registers it in orbit's `extensions.load`, and restarts orbit. The binaries are committed in this directory, so no release is needed; rebuild with `make build` and commit when the source changes.

The ACL step is what makes this work on Windows. orbit does not pass `--allow_unsafe`, and osquery refuses to autoload an extension whose Windows ACLs are inherited rather than explicit, so the installer runs:

```
icacls <dir> /setowner *S-1-5-32-544 /t /c /q
icacls <dir> /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" /t /c /q
icacls <dir> /inheritance:r /t /c /q
```

Test interactively without deploying:

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
