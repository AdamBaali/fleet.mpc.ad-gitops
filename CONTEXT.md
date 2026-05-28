# Windows YellowKey (CVE-2026-45585) mitigation context

Context for Claude Code working on the YellowKey pattern in this repo. Read this first.

## The threat

YellowKey (CVE-2026-45585, disclosed May 12 2026) is an unpatched BitLocker bypass. `autofstx.exe` inside the Windows Recovery Environment replays NTFS transaction logs from any attached volume's `System Volume Information\FsTx` folder, deletes `winpeshl.ini`, and drops the attacker into `cmd.exe` with the BitLocker volume unlocked. Brief physical access is enough.

Affects Windows 11, Server 2022, Server 2025. Windows 10 ships a different WinRE component and is not affected. Microsoft published a mitigation on May 19 2026; no full patch yet.

Microsoft's mitigation strips `autofstx.exe` from the WinRE image's Session Manager `BootExecute`. `reagentc /disable` is a heavier alternative that removes WinRE entirely. TPM + PIN blocks the published PoC but not the researcher's withheld variant. USB-block GPOs and BIOS USB-boot blocks do not help: WinRE ignores OS USB policy, and the attack does not boot from the stick.

## What's in this repo

```
extensions/
└── windows_yellowkey/                       # osquery extension exposing the windows_yellowkey table
    ├── main.go                              # Go source
    ├── go.mod / go.sum                      # Go module
    ├── Makefile                             # Cross-compile windows/amd64 + arm64
    └── README.md                            # Build + deploy + sample queries

lib/windows/
├── reports/
│   └── windows-yellowkey.reports.yml        # Daily per-host verdict (queries the extension table)
├── policies/
│   └── windows-yellowkey-extension.policies.yml  # Keeps the extension installed; run_script installs on failure
└── scripts/
    ├── install-yellowkey-extension.ps1      # Download + load the extension (place + extensions.load + restart orbit)
    └── mitigate-windows-yellowkey.ps1       # autofstx strip from WinRE BootExecute (Microsoft's mitigation)

.github/workflows/build-extensions.yml        # On tag push, builds every extensions/<name>/ and uploads binaries as release assets
articles/windows-yellowkey-mitigation.md      # Customer-facing guide
```

Referenced from `fleets/workstations.yml` (`policies`, `reports`, `controls.scripts`).

## How detection works

The `windows_yellowkey` osquery extension reads, on every query: OS (registry `ProductName`), WinRE state (`reagentc /info`), BitLocker key protectors (`Get-BitLockerVolume`), and the Fleet `BootExecMitigated` marker. It derives one `state` per host. No snapshot file, no freshness gate, every query is live.

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

The `windows-yellowkey-extension` policy checks `osquery_registry` for the `windows_yellowkey` table plugin (`SELECT 1 FROM osquery_registry WHERE registry = 'table' AND name = 'windows_yellowkey' AND active = 1`). It returns one row when the extension is loaded (pass) and zero rows when it is not (fail). Querying the `windows_yellowkey` table directly would error when the extension is absent, which Fleet shows as neither pass nor fail and would not trigger the installer. Failing hosts run `install-yellowkey-extension.ps1`, which downloads the architecture-matching binary, places it under `C:\Program Files\Orbit\extensions\`, adds the path to `extensions.load`, hardens the ACLs, and restarts the `Fleet osquery` service. osquery autoloads the extension on the next start.

The prebuilt binaries (`windows_yellowkey-amd64.exe`, `windows_yellowkey-arm64.exe`) are committed under `extensions/windows_yellowkey/`. `install-yellowkey-extension.ps1` reads `PROCESSOR_ARCHITECTURE` and pulls the matching one from the repo's raw URL on `main`. No release or tag to cut. Rebuild with `make build` and commit when the extension changes.

fleetd regenerates `osquery.flags` from agent options on every config refresh, so the flags that enable extensions live there, not in `osquery.flags`. Editing `osquery.flags` by hand is the most common reason a manual extension deployment silently breaks: it works once, then orbit overwrites the change on the next refresh. `fleets/workstations.yml` sets `disable_extensions: false`, `extensions_autoload: 'C:\Program Files\Orbit\extensions.load'`, `extensions_timeout: 10`, and `extensions_interval: 3` under the top-level `agent_options.command_line_flags`. These are osqueryd command-line flags, not config options; Fleet rejects them under `options` (`"disable_extensions" should be part of the "command_line_flags" object`) and also rejects `command_line_flags` under `overrides.platforms.<platform>` (`"command_line_flags" should be part of the top level object`), so they apply to every platform on the team. On macOS and Linux hosts the autoload path does not exist; osquery logs one warning at startup then continues without autoloading anything. Set it in `fleets/workstations.yml` for GitOps, or under **Settings > Organization settings > Agent options** (global) or **Settings > Teams > [team] > Agent options** in the Fleet UI. The YAML layout reference is at https://fleetdm.com/docs/configuration/yaml-files and the agent options reference at https://fleetdm.com/docs/configuration/agent-configuration.

The installer hardens the extensions directory, the binary, and `extensions.load` to owner Administrators, no inherited ACEs, full control for Administrators and SYSTEM, read+execute for Users (`.NET FileSystemAccessRule`, well-known SIDs so it works on non-English Windows). It writes `extensions.load` as ASCII with no BOM through `[System.IO.File]::WriteAllLines`; a UTF-16 or UTF-8-BOM file makes osquery skip the loader and load zero extensions silently. The download is verified by SHA-256 against a value committed in the script, one per architecture; rebuilding the binary requires bumping that hash in the same commit. For a catalog of extensions, Fleet's other supported path is orbit's managed extension set on a self-hosted TUF server (`fleetctl updates add` plus the global or team extension config); the in-script approach used here scales by one entry per extension in the script and the loader file. Fleet caps policy `run_script` retries at 3 per failure; the script is idempotent, so a host that drifted from the hardened state self-heals on the next remediation.

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

- Read this file before editing the scripts or the extension.
- The verdict logic lives in `extensions/windows_yellowkey/main.go` (`verdict()`), not in the report YAML. The report just surfaces the `state` column. If you change the verdicts, update the extension, the report description, the README, and the article together.
- After editing the extension, run the build and lint checks below before committing.

Extension build + lint (from `extensions/windows_yellowkey/`):

```bash
gofmt -l .
GOOS=windows GOARCH=amd64 go vet .
make build
```

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
