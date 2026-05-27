# YellowKey osquery extension (CVE-2026-45585)

Native osquery extension that exposes per-host exposure and mitigation state for the YellowKey BitLocker bypass (CVE-2026-45585). Replaces the `snapshot-windows-yellowkey.ps1` + `file_lines` approach with a real-time virtual table.

Pattern adapted from [`allenhouchins/fleet-extensions/secureboot_cert_update`](https://github.com/allenhouchins/fleet-extensions/tree/main/secureboot_cert_update).

## What it does

Registers a single virtual osquery table, `windows_yellowkey`. Each query returns one row per host with derived state + raw signals:

| Column | Type | Meaning |
|---|---|---|
| `state` | text | `not_affected`, `mitigated`, `mitigated_winre_off`, `bitlocker_off`, `exposed`, `unknown` |
| `state_reason` | text | Human-readable explanation |
| `needs_action` | int | `1` if the host is exposed, `0` otherwise |
| `action` | text | `apply_mitigation`, `verify_winre_state`, `verify_periodically`, `monitor`, `none` |
| `cve` | text | `CVE-2026-45585` |
| `os_name` | text | From `HKLM\Software\Microsoft\Windows NT\CurrentVersion\ProductName` |
| `os_build` | text | Same key, `CurrentBuild` value |
| `affected_os` | int | `1` for Windows 11, Server 2022, Server 2025 |
| `winre_enabled` | text | `Enabled`, `Disabled`, or `unknown` (locale parse failure) |
| `winre_location` | text | WinRE image path from `reagentc /info` |
| `bitlocker_volume_count` | int | Count from `Get-BitLockerVolume` |
| `bitlocker_protected_count` | int | Volumes with `ProtectionStatus = On` |
| `bitlocker_max_protection_status` | int | Maximum protection_status across volumes |
| `bitlocker_key_protectors` | text | Sorted comma-separated unique types (e.g. `Tpm,TpmPin`) |
| `bitlocker_tpm_only_count` | int | Volumes with TPM but no PIN (most vulnerable) |
| `bootexec_mitigated_marker` | int | `1` if `HKLM\Software\Fleet\YellowKey\BootExecMitigated` = 1 |
| `collection_time` | text | RFC 3339 UTC |
| `extension_schema_version` | text | `1.0.0` |

The extension does **not** mount the WinRE image to inspect the offline `BootExecute` value on every query. The `BootExecMitigated` marker (written by `mitigate-windows-yellowkey.ps1` on success) is the proxy. For ground truth, re-run `mitigate-windows-yellowkey.ps1`: it is idempotent and reports the live `BootExecute` contents.

## State derivation

Order of precedence (first match wins):

1. **`not_affected`**: `affected_os = 0` (Windows 10, etc.)
2. **`mitigated`**: `BootExecMitigated` marker set
3. **`mitigated_winre_off`**: WinRE disabled
4. **`bitlocker_off`**: no BitLocker volume is protecting
5. **`exposed`**: affected OS + BitLocker on + WinRE on (or WinRE state unknown)

## Microsoft's mitigation source

The mitigation this extension watches the after-effects of is Microsoft's canonical script, published inside the [CVE-2026-45585 MSRC advisory](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585) FAQ under *"Is there a script that I can copy and paste to implement a mitigation?"*. Microsoft's flow:

1. `reagentc /mountre /path <dir>` to mount the WinRE image.
2. `reg load` the offline SYSTEM hive.
3. Walk active ControlSets, strip `autofstx.exe` from `Control\Session Manager\BootExecute`.
4. `reg unload`, `reagentc /unmountre /commit`.
5. `reagentc /disable` + `/enable` to re-seal the BitLocker measurement chain.

The Fleet wrapper that calls this flow is `lib/windows/scripts/mitigate-windows-yellowkey.ps1` in this repo. The wrapper adds an opt-in marker gate, a success marker, an ACL-locked mount path, full ControlSet enumeration (covers `LastKnownGood` and `Failed`), and a broader `(?i)\bautofstx(\.exe)?\b` regex so `autocheck autofstx`, `autofstx`, and `autofstx.exe /flag` all match.

## Build

Requires Go 1.21 or newer. From this directory:

```bash
make deps
make windows
```

Produces `windows_yellowkey-amd64.exe` and `windows_yellowkey-arm64.exe`. The Makefile cross-compiles from any host platform (Linux, macOS, Windows).

## Deploy / test

Same pattern as the Allen Houchins reference: drop the compiled binary on a Windows host and load it through `orbit shell`. Interactive REPL for testing:

```powershell
'C:\Program Files\Orbit\bin\orbit\orbit.exe' shell -- --extension .\windows_yellowkey-amd64.exe --allow-unsafe
```

Once at the osquery prompt:

```sql
SELECT state, state_reason, needs_action, action FROM windows_yellowkey;
SELECT * FROM windows_yellowkey;
```

For Fleet rollouts, place the binary at a known path (e.g., `C:\Program Files\Orbit\bin\orbit\extensions\windows_yellowkey-amd64.exe`) and load it via orbit's extensions autoload. Document any path / config decisions alongside the binary release.

## Sample Fleet queries

Count exposed hosts:

```sql
SELECT COUNT(*) AS exposed_hosts
FROM windows_yellowkey
WHERE state = 'exposed';
```

Group every responding host by state:

```sql
SELECT state, COUNT(*) AS hosts
FROM windows_yellowkey
GROUP BY state;
```

Find TPM-only hosts (most vulnerable to the published PoC):

```sql
SELECT os_name, os_build, bitlocker_tpm_only_count, state
FROM windows_yellowkey
WHERE state = 'exposed' AND bitlocker_tpm_only_count > 0;
```

Find hosts where Fleet thinks they are mitigated but WinRE state cannot be confirmed:

```sql
SELECT os_name, bootexec_mitigated_marker, winre_enabled
FROM windows_yellowkey
WHERE bootexec_mitigated_marker = 1 AND winre_enabled = 'unknown';
```

## Permissions

- **Registry read:** `HKLM\Software\Fleet\YellowKey`, `HKLM\Software\Microsoft\Windows NT\CurrentVersion`.
- **Shell out:** `reagentc.exe /info`, `powershell.exe -NoProfile -NonInteractive -Command "Get-BitLockerVolume ..."`.
- Runs inside orbit's privileged context. No elevation prompt.

## Schema versioning

The `extension_schema_version` column is included so future Fleet queries can branch on the schema. Bump it whenever you add, remove, or rename columns or materially change the meaning of `state`.

## Mapping to the report

| Extension column | Report column / verdict |
|---|---|
| `state = 'not_affected'` | `yellowkey_exposure_verdict = 'not_affected'` |
| `state = 'mitigated'` | `yellowkey_exposure_verdict = 'mitigated'` |
| `state = 'mitigated_winre_off'` | `yellowkey_exposure_verdict = 'mitigated_winre_off'` |
| `state = 'bitlocker_off'` | `yellowkey_exposure_verdict = 'bitlocker_off'` |
| `state = 'exposed'` | `yellowkey_exposure_verdict = 'exposed'` |

A future revision of `windows-yellowkey.reports.yml` can query `windows_yellowkey` directly and drop the `file_lines` snapshot pivot. The snapshot path stays available as a fallback for hosts without the extension loaded.

## Caveats

- The WinRE regex is CJK-colon tolerant (`[:：]`) but the status words (`Enabled` / `Disabled`) are still English-only. On a non-English Windows install, the parse falls through to `unknown` and the `state` becomes `exposed` (the safe default).
- The extension does not detect a host that has been mitigated via `reagentc /disable` directly (without going through `mitigate-windows-yellowkey.ps1`) unless the snapshot script also recorded the WinRE state. With the extension querying `reagentc /info` on every call, this case shows up as `mitigated_winre_off` correctly.
- The `BootExecMitigated` marker is not auto-cleared. If Microsoft ships a patch and admins want to retire the marker, clear `HKLM\Software\Fleet\YellowKey\BootExecMitigated` via Fleet scripts or registry update.
