# Windows YellowKey (CVE-2026-45585) mitigation context

Context for Claude Code working on the YellowKey pattern in this repo. Read this first.

## The threat

YellowKey (CVE-2026-45585, disclosed May 12 2026) is an unpatched BitLocker bypass. `autofstx.exe` inside the Windows Recovery Environment replays NTFS transaction logs from any attached volume's `System Volume Information\FsTx` folder, deletes `winpeshl.ini`, and drops the attacker into `cmd.exe` with the BitLocker volume unlocked. Brief physical access is enough.

Affects Windows 11, Server 2022, Server 2025. Windows 10 ships a different WinRE component and is not affected. Microsoft published a mitigation on May 19 2026; no full patch yet.

Microsoft's mitigation strips `autofstx.exe` from the WinRE image's Session Manager `BootExecute`. `reagentc /disable` is a heavier alternative that removes WinRE entirely. TPM + PIN blocks the published PoC but not the researcher's withheld variant. USB-block GPOs and BIOS USB-boot blocks do not help: WinRE ignores OS USB policy, and the attack does not boot from the stick.

## What's in this repo

The Fleet-consumer side. The osquery extension (Go source + binaries + CI) lives upstream in [`allenhouchins/fleet-extensions/windows_yellowkey`](https://github.com/allenhouchins/fleet-extensions/tree/main/windows_yellowkey); this repo holds the policy, report, and the two PowerShell scripts that install and mitigate.

```
lib/windows/
├── reports/
│   └── windows-yellowkey.reports.yml        # Daily per-host verdict (queries the extension table)
├── policies/
│   └── windows-yellowkey-extension.policies.yml  # Keeps the extension installed; run_script installs on failure
└── scripts/
    ├── install-yellowkey-extension.ps1      # Thin wrapper: fetches the upstream installer and runs it
    └── mitigate-windows-yellowkey.ps1       # autofstx strip from WinRE BootExecute (Microsoft's mitigation)

articles/windows-yellowkey-mitigation.md      # Customer-facing guide
```

Referenced from `fleets/workstations.yml` (`policies`, `reports`, `controls.scripts`).

## How detection works

The `windows_yellowkey` osquery extension reads, on every query: OS (registry `ProductName` plus `CurrentBuild` for Windows 11 detection, since Microsoft never updated `ProductName` past "Windows 10"; Win11 starts at build 22000), WinRE state (`reagentc /info`), BitLocker key protectors (`Get-BitLockerVolume`), and the Fleet `BootExecMitigated` marker. It derives one `state` per host. No snapshot file, no freshness gate, every query is live.

Verdicts (first match wins, in `verdict()` in main.go):

- `not_affected`: Windows 10 or unrecognised SKU
- `mitigated`: BootExecMitigated marker set
- `mitigated_winre_off`: WinRE disabled
- `bitlocker_off`: no protected BitLocker volume
- `exposed`: affected OS + BitLocker on + no mitigation

The report (`windows-yellowkey.reports.yml`) is a one-line `SELECT ... FROM windows_yellowkey`; the verdict logic lives in the extension, not the SQL. A host returns a row only once the extension is loaded.

## Mitigation

`mitigate-windows-yellowkey.ps1` adapts Microsoft's reference script from the CVE-2026-45585 MSRC FAQ:

1. `reagentc /mountre` to mount the WinRE image.
2. `reg load` the offline SYSTEM hive.
3. Walk every ControlSet, strip `autofstx` variants from `Control\Session Manager\BootExecute`, verify by read-back.
4. `reg unload`, `reagentc /unmountre /commit`.
5. `reagentc /disable` + `/enable` to re-seal the BitLocker measurement chain.

Fleet specifics:

- Mount path under `%SystemRoot%\Temp`, ACL-locked to Administrators.
- Mount + edit + unmount in one try/finally so the hive and mount are always released.
- Writes `HKLM\SOFTWARE\Fleet\YellowKey\BootExecMitigated = 1` only when every ControlSet verified clean. The extension reads this marker to report `mitigated`.
- No opt-in gate; Microsoft's strip is safe on every affected host. One-way: no unmitigate. If a patch ships, apply it and clear the marker.

Exit codes:

| Code | Meaning |
|------|---------|
| 0 | autofstx removed, already absent, or WinRE already disabled |
| 3 | OS not affected (Windows 10 etc.); no action taken |
| 4 | Mount, edit, unmount, or re-seal failed; manual investigation needed |

## Deployment

The `windows-yellowkey-extension` policy checks `osquery_registry` for the `windows_yellowkey` table plugin (`SELECT 1 FROM osquery_registry WHERE registry = 'table' AND name = 'windows_yellowkey' AND active = 1`). It returns one row when the extension is loaded (pass) and zero rows when it is not (fail). Querying the `windows_yellowkey` table directly would error when the extension is absent, which Fleet shows as neither pass nor fail and would not trigger the installer. Failing hosts run `install-yellowkey-extension.ps1`, which downloads the architecture-matching binary, places it under `C:\Program Files\osquery\extensions\`, adds the path to `C:\Program Files\osquery\extensions.load`, hardens the ACLs, and restarts the `Fleet osquery` service. osqueryd autoloads the extension on the next start.

The prebuilt binaries (`windows_yellowkey-amd64.exe`, `windows_yellowkey-arm64.exe`) live upstream in [`allenhouchins/fleet-extensions/windows_yellowkey`](https://github.com/allenhouchins/fleet-extensions/tree/main/windows_yellowkey); Allen's CI rebuilds them on every push to `main` and republishes the `latest` release. The script at `lib/windows/scripts/install-yellowkey-extension.ps1` is a thin wrapper that downloads `install-windows-yellowkey-extension.ps1` from Allen's `main` branch and runs it; the upstream script reads `PROCESSOR_ARCHITECTURE`, pulls the matching asset from `releases/latest/download`, validates the PE header, and places the binary. The wrapper exists because Fleet's GitOps `run_script` needs a file on disk to upload; the actual install logic lives upstream and never needs syncing here.

The script writes to osquery's compiled-in default autoload path on Windows, not to orbit's directory. `<orbit-root-dir>\extensions.load` is owned by orbit's `ExtensionRunner` (`orbit/pkg/update/flag_runner.go`), which truncates the file on every config refresh unless Fleet has TUF-managed extensions configured under `agent_options.extensions`. Fleet's API also rejects setting `extensions_autoload` directly in agent options (`server/fleet/agent_options.go`: `"The --extensions_autoload flag isn't supported."`). orbit only passes `--extensions_autoload` to osqueryd when its own loader file is non-empty (`orbit/cmd/orbit/orbit.go`), so on a fleet with no TUF-managed extensions osqueryd falls back to its compiled default. That default is `OSQUERY_HOME "extensions.load"`, and `OSQUERY_HOME` for WIN32 is `"\\Program Files\\osquery\\"` per [osquery's `default_paths.h`](https://github.com/osquery/osquery/blob/master/osquery/utils/config/default_paths.h), so on Windows the path resolves to `C:\Program Files\osquery\extensions.load`. The script writes there. This is the Windows twin of Allen Houchins' Linux/macOS installers that write to `/etc/osquery/extensions.load` and `/var/osquery/extensions.load`. No agent options touch this path, no TUF update server is needed, and no scheduled task wraps osqueryd.

The installer hardens the extensions directory, the binary, and `extensions.load` to owner Administrators, no inherited ACEs, full control for Administrators and SYSTEM, read+execute for Users (`.NET FileSystemAccessRule`, well-known SIDs so it works on non-English Windows). It writes `extensions.load` as ASCII with no BOM through `[System.IO.File]::WriteAllLines`; a UTF-16 or UTF-8-BOM file makes osquery skip the loader and load zero extensions silently. The download is sanity-checked by reading the first two bytes (PE32+ files open with `MZ`), which catches truncated downloads and HTML 404 pages without pinning a hash in source. For a catalog of extensions, Fleet's other supported path is orbit's managed extension set on a self-hosted TUF server (`fleetctl updates add` plus the global or team extension config); the in-script approach used here scales by one entry per extension in the script and the loader file. Fleet caps policy `run_script` retries at 3 per failure; the script is idempotent, so a host that drifted from the hardened state self-heals on the next remediation.

## Style guide for any updates

Fleet "no fluff, no fear" style:

- Short, declarative sentences. Active voice.
- Sentence case headings. No title case.
- No em dashes. Replace with commas, colons, or new sentences.
- Banned words: very, really, actually, basically, essentially, just, powerful, seamless, revolutionary, game-changing.
- Use "hosts" not "endpoints" or "agents".
- Use "BitLocker" only for Windows BitLocker contexts; "disk encryption" generally.
- Copy-ready outputs over explanatory prose.
- Don't add comments that restate the code. Add comments that explain *why* a non-obvious choice was made.

PowerShell specifics:

- `$ErrorActionPreference = 'Stop'` for scripts that mutate.
- Empty catch blocks are not allowed. Always surface `$_.Exception.Message`.
- Use `$null -ne $var` not `if ($var)` for value checks; `0` is falsey in PowerShell.
- Structured key:value output via the `Write-State` helper (width 30).

osquery / Go specifics:

- The extension follows the Go Code Review Comments conventions: package comment starts with "Package ...", no silent error discards (log unexpected failures, stay quiet on expected absence such as a missing Fleet registry key), enumerated string values declared as constants, `gofmt` and `go vet` clean.
- osquery integer columns are strings (`"1"` / `"0"`).
- Match table column names exactly between the extension and the report query.
- An autoloaded extension must accept `--verbose`. osqueryd forwards it when it runs verbose, and a bare `flag.Parse()` (ExitOnError) exits on the unknown flag, so the table never registers. Declare the flag even if it goes unused.

## Working with Claude Code

When making changes:

- Read this file before editing the scripts.
- The verdict logic lives upstream in [`allenhouchins/fleet-extensions/windows_yellowkey/main.go`](https://github.com/allenhouchins/fleet-extensions/blob/main/windows_yellowkey/main.go) (`verdict()`), not in the report YAML. The report surfaces the `state` column. If the verdicts change upstream, update the report description and the article in this repo to match. The installer pulls from `releases/latest/download` and needs no change when the upstream binary is republished.

PowerShell lint (from `lib/windows/scripts/`):

```bash
for f in *.ps1; do
  echo "=== $f ==="
  grep -nE 'catch *\{ *\}' "$f" && echo "  empty catch found" || echo "  ok: no empty catches"
  grep -nE 'if \(\$[a-zA-Z]+(Status|Error|Capable|Available)\)' "$f" && echo "  boolean coercion" || echo "  ok: explicit null"
done
```

## References

- **CVE-2026-45585 (YellowKey)**: https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585 (FAQ contains Microsoft's canonical mitigation script)
- **Eclypsium analysis**: https://eclypsium.com/blog/yellowkey-bitlocker-bypass-windows-recovery-environment/
- **Extension pattern (Allen Houchins)**: https://github.com/allenhouchins/fleet-extensions/tree/main/secureboot_cert_update
- **Fleet custom extensions guide**: https://fleetdm.com/guides/deploying-custom-osquery-extensions-in-fleet-a-step-by-step-guide
