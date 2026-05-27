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

The `windows-yellowkey-extension` policy runs `SELECT 1 FROM windows_yellowkey`. It passes only when the extension is loaded, so it tests the real end state, not a file on disk. Failing hosts run `install-yellowkey-extension.ps1`, which downloads the architecture-matching binary, places it under `C:\Program Files\Orbit\extensions\`, registers it in orbit's `extensions.load`, and restarts orbit.

Binaries come from a tag push (`v*` or `extensions-v*`). `.github/workflows/build-extensions.yml` builds every `extensions/<name>/` via `make windows` and uploads the `.exe` files as release assets. `install-yellowkey-extension.ps1` pulls from `releases/latest/download/`. Fleet caps policy `run_script` retries at 3 per failure.

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

## Working with Claude Code

When making changes:

- Read this file before editing the scripts or the extension.
- The verdict logic lives in `extensions/windows_yellowkey/main.go` (`verdict()`), not in the report YAML. The report just surfaces the `state` column. If you change the verdicts, update the extension, the report description, the README, and the article together.
- After editing the extension, run the build and lint checks below before committing.

Extension build + lint (from `extensions/windows_yellowkey/`):

```bash
gofmt -l .
GOOS=windows GOARCH=amd64 go vet .
make windows
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
