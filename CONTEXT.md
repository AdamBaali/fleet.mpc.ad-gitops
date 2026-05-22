# Windows Secure Boot CA 2023 migration — context

Context for Claude Code working on the CA 2023 detection and remediation pattern in this repo. Read this first.

## Problem

Microsoft is replacing the **Windows Production PCA 2011** certificate with **Windows UEFI CA 2023** across the Secure Boot trust chain. Same root cause drives three problems:

1. **CVE-2023-24932 (BlackLotus)** — bootkit swaps `bootmgfw.efi` for a vulnerable version signed by the still-trusted PCA 2011 cert, bypasses BitLocker on next boot.
2. **CVE-2025-48804 (BitUnlocker)** — downgrade attack: an attacker with brief physical access drops a pre-July-2025 boot manager onto the ESP, which firmware still trusts because PCA 2011 is in DB and not revoked in DBX. Decrypts a TPM-only BitLocker volume in under 5 minutes. Patched in July 2025 CU, but the patch alone does not close the path. DBX revocation closes the path.
3. **PCA 2011 expiry (October 2026)** — anything still chained to PCA 2011 stops receiving Secure Boot servicing.

Microsoft ships the fix as one coordinated migration via KB5025885: `AvailableUpdates = 0x5944` triggers cert update + boot manager update + DBX revocation. Patching alone is not enough. Windows Server does not auto-migrate. Even on auto-rolling clients, the migration runs in a multi-reboot state machine and customers want visibility.

The repo's migrate/verify scripts target this single migration. Completing it
closes BlackLotus and BitUnlocker simultaneously, because both depend on PCA 2011
remaining trusted.

## What's in this repo

```
lib/windows/
├── reports/
│   ├── windows-ca-2023.reports.yml          # CA 2023 migration state (daily snapshot)
│   └── windows-yellowkey.reports.yml        # YellowKey OS + BitLocker exposure
├── scripts/
│   ├── migrate-windows-ca-2023.ps1          # CA 2023 idempotent remediation
│   ├── verify-windows-ca-2023.ps1           # CA 2023 firmware-level inspection (human-readable)
│   ├── snapshot-windows-ca-2023.ps1         # CA 2023 firmware state writer (with freshness timestamp)
│   ├── cleanup-windows-ca-2023-snapshot.ps1 # CA 2023 snapshot deletion (force native fallback)
│   ├── mitigate-windows-yellowkey.ps1       # YellowKey: autofstx strip from WinRE BootExecute (Microsoft's mitigation, no gate)
│   ├── verify-windows-yellowkey.ps1         # YellowKey: WinRE + BitLocker inspection (human-readable)
│   ├── snapshot-windows-yellowkey.ps1       # YellowKey state writer (with freshness timestamp)
│   ├── cleanup-windows-yellowkey-snapshot.ps1 # YellowKey snapshot deletion (force native fallback)
│   └── install-yellowkey-extension.ps1      # YellowKey: download + install the osquery extension binary
└── policies/
    └── windows-yellowkey-extension.policies.yml # Policy: extension binary present; runs install-yellowkey-extension.ps1 on failure

extensions/                                 # Native osquery extensions (Go). One subdirectory per extension.
└── windows_yellowkey/                      # Exposes the windows_yellowkey table for CVE-2026-45585 detection
    ├── main.go                             # Extension implementation
    ├── go.mod / go.sum                     # Go module
    ├── Makefile                            # Cross-compile windows/amd64 + arm64
    └── README.md                           # Build + deploy + sample queries

.github/workflows/build-extensions.yml       # On tag push, builds every extensions/<name>/ and uploads binaries as release assets
```

Reports use native osquery tables (`authenticode`, `registry`, `os_version`, `bitlocker_info`) plus snapshot data via `file_lines` for signals osquery cannot reach natively. Each report applies a 48-hour freshness gate: snapshot data older than 48 hours is treated as missing and snapshot-derived verdicts fall back to the native-only set. Re-run the matching `snapshot-windows-*.ps1` to refresh.

The optional `windows_yellowkey` osquery extension (`extensions/windows_yellowkey/`) provides the same YellowKey signals as a real-time virtual table, eliminating the snapshot freshness gate for hosts that load the extension. Pattern adapted from [`allenhouchins/fleet-extensions/secureboot_cert_update`](https://github.com/allenhouchins/fleet-extensions/tree/main/secureboot_cert_update). Build with `make windows`, deploy via `orbit.exe shell -- --extension <binary> --allow-unsafe`. Snapshot scripts remain as the fallback path for hosts without the extension loaded.

Releases: pushing a tag matching `v*` or `extensions-v*` triggers `.github/workflows/build-extensions.yml`, which auto-discovers every directory under `extensions/`, runs `make windows` in each, and uploads the resulting `.exe` files as assets on a GitHub release. The `install-yellowkey-extension.ps1` script (attached to the `windows-yellowkey-extension` policy) pulls from that release URL.

Referenced from `fleets/workstations.yml` `controls.scripts` and `reports`.

## How detection works

The migration runs in two layers that can drift:

| Layer | What it is | Where to look |
|-------|------------|---------------|
| **Firmware-level** | The cert lives in firmware DB; boot manager on the EFI System Partition | `mountvol S: /s` then read `S:\EFI\Microsoft\Boot\bootmgfw.efi`. Only PowerShell with admin can see this. osquery cannot. Captured by `snapshot-windows-ca-2023.ps1`. |
| **OS-side staging** | `C:\Windows\Boot\EFI\bootmgfw.efi` and friends, copied to ESP at the next servicing pass | `authenticode` table. osquery sees this. |
| **Registry state machine** | Microsoft's own per-host servicing status | `HKLM\...\SecureBoot\Servicing` keys. osquery sees this. |

**File signatures alone produce false negatives.** A host can be fully migrated at firmware level while the OS-side `bootmgfw.efi` still shows PCA 2011. Windows Update refreshes the staging copy on its own cycle. The registry servicing state is the authoritative answer for "has firmware migrated."

The report combines all three layers and applies a 48-hour freshness gate to snapshot data. Verdicts:

- `compliant_via_files` -- OS-side binary signed by CA 2023 (best case)
- `compliant_via_firmware` -- ESP boot manager signed by CA 2023 (fresh snapshot only)
- `compliant_via_registry` -- registry says `Updated`, files may still lag (firmware is done)
- `in_progress` -- registry says `InProgress` (servicing running)
- `errored` -- `UEFICA2023Error != 0` (Event ID 1801 / 1803)
- `not_started_ready_to_trigger` -- firmware DB has CA 2023, never triggered (fresh snapshot only)
- `not_started_cu_missing` -- firmware DB lacks CA 2023, no CU yet (fresh snapshot only)
- `not_started` -- none of the above

Verify hosts in `compliant_via_registry` by running `verify-windows-ca-2023.ps1`. It reads the firmware DB and ESP boot manager directly to confirm.

## Snapshot pattern (firmware visibility in osquery)

osquery has no EFI-variable table and no Secure Boot / WinRE tables, so the firmware DB, KEK, DBX, ESP boot manager signature, and WinRE state cannot be read natively. `snapshot-windows-ca-2023.ps1` and `snapshot-windows-yellowkey.ps1` capture those signals as `key=value` text files; the reports `LEFT JOIN file_lines` and pivot rows into columns.

State files (ASCII, no BOM, one key=value per line):

```
C:\ProgramData\Fleet\state\windows-ca-2023-snapshot.txt
C:\ProgramData\Fleet\state\windows-yellowkey-snapshot.txt
```

Each snapshot writes a `snapshot_generated` value in ISO 8601 UTC. The reports compute `snapshot_age_hours` and assign `snapshot_status`: `fresh` (< 48 hours), `stale` (>= 48 hours), or `missing` (no file). Stale and missing both null out the snapshot columns in the report, so snapshot-derived verdicts only fire when fresh. Both columns are surfaced in the report so admins see freshness at a glance.

Refresh options (admin's choice):

1. **Fleet > Scripts** -- run `snapshot-windows-*.ps1` against a label on the cadence you want.
2. **Host-side scheduled task** -- wrap the script. No installer ships in this repo yet.
3. **`cleanup-windows-*-snapshot.ps1`** -- delete the state file to force native-only fallback on the next report run.

**Why no policy auto-remediation?** Fleet caps policy `run_script` re-runs at 3 retries per failure. A daily-refresh need would burn through those retries fast and leave the policy permanently failing, which also blocks attaching the real compliance remediation (`migrate-windows-ca-2023.ps1`) to that slot later. The snapshot is purely a visibility booster; treat it as opt-in.

## Registry servicing state machine

`HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing`:

| Value | Meanings |
|-------|----------|
| `WindowsUEFICA2023Capable` | `0` = not capable (no CU), `1` = capable, `2` = migrated |
| `UEFICA2023Status` | `NotStarted`, `InProgress`, `Updated` |
| `UEFICA2023Error` | `0` or absent = no error; non-zero = errored |

`HKLM:\SYSTEM\CurrentControlSet\Control\Secureboot`:

| Value | Meanings |
|-------|----------|
| `AvailableUpdates` | `0x5944` = full migration trigger; `0x4100` = reboot pending; `0` = cleared after task picked it up |

Microsoft also documents granular bitmask values for staged rollouts. The repo
uses `0x5944` for the all-in-one trigger because it is the only value KB5025885
recommends for fleet-wide deployment and it remains idempotent across reboots:

| Value | Mitigation step |
|-------|-----------------|
| `0x140` | Install CA 2023 to DB + update boot manager (Mitigations 1+2) |
| `0x80`  | Add PCA 2011 to DBX (Mitigation 3, revocation) |
| `0x200` | Apply SVN update to firmware (Mitigation 4) |
| `0x280` | Mitigations 3+4 combined |
| `0x5944` | Full migration (all four mitigations) |

## Event IDs to monitor

In `Event Viewer > Windows Logs > System`:

| ID | Meaning |
|----|---------|
| `1036` | PCA 2023 added to DB (success) |
| `1037` | PCA 2011 added to DBX (revocation success) |
| `1795` | Generic DB / DBX update event (see KB5016061) |
| `1799` | Boot manager signed by CA 2023 applied (success) |
| `1801` | DB update blocked |
| `1803` | No PK-signed KEK present |

## Migration trigger

`Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\Secureboot -Name AvailableUpdates -Value 0x5944 -Type DWord` then `Start-ScheduledTask -TaskPath "\Microsoft\Windows\PI\" -TaskName "Secure-Boot-Update"`.

Microsoft clears `AvailableUpdates` to `0` once the task picks it up. Re-trigger by re-setting and re-starting.

Multi-reboot. Sometimes 2 reboots, sometimes more. The script is idempotent — safe to re-run after each reboot.

## Script exit codes

`migrate-windows-ca-2023.ps1`:

| Code | Meaning |
|------|---------|
| 0 | Migration complete, in progress, or just triggered |
| 2 | Secure Boot not enabled (or check failed — BIOS/legacy) |
| 3 | CU too old, OR Secure-Boot-Update task failed to start |
| 4 | `UEFICA2023Error != 0` — manual investigation needed |
| 5 | Reboot pending |
| 6 | Boot file missing or signature unreadable — remediation skipped |

`verify-windows-ca-2023.ps1`: always exits 0 unless PowerShell itself errors. The output is the deliverable.

## Microsoft enforcement timeline

Three separate 2011 certs are involved, each with a different expiry:

| Cert | Expiry |
|------|--------|
| Microsoft UEFI CA 2011 (third-party UEFI loaders) | June 2026 |
| Microsoft Windows Production PCA 2011 (boot manager signing) | October 2026 |
| Microsoft Corporation KEK CA 2011 (Key Exchange Key) | October 19, 2026 |

Microsoft staggers user-visible enforcement in three phases:

| Phase | Start | Behaviour |
|-------|-------|-----------|
| Initial | May 13 2026 (Win10), May 16 2026 (Win11) | Yellow advisory banner |
| Intermediate | Q3 2026 | Orange banner + full-screen notifications |
| Enforcement | October 2026 | KEK 2011 expires; non-migrated hosts stop receiving Secure Boot servicing |

Plan rollout backwards from the Enforcement Phase. The repo defaults assume
the goal is migration well ahead of October 2026.

## Known gotchas

1. **ESP boot manager is the real one.** `C:\Windows\Boot\EFI\bootmgfw.efi` is a staging copy. Firmware loads from `\Device\HarddiskVolumeX\EFI\Microsoft\Boot\bootmgfw.efi` on the ESP. Use `mountvol S: /s` to mount it temporarily, then `mountvol S: /d` to dismount.
2. **Servicing state and file signatures drift.** Expect `Updated` registry state with PCA 2011 files for hours-to-days after migration. Not a bug.
3. **PCA 2011 expiry is October 2026, not June 2026.** June 2026 is the third-party `Microsoft UEFI CA 2011`. The Windows boot-signing PCA 2011 expires in October 2026, same month as the KEK CA 2011. Anything still chained to PCA 2011 after October 2026 stops receiving Secure Boot servicing.
4. **Recovery media built before migration breaks after DBX revocation.** Rebuild WinRE / install media against CA 2023 sources before pushing migration broadly.
5. **OEM caveats:**
   - **Lenovo** — CA 2023 and KEK 2K CA 2023 already in firmware fleet-wide. Lowest risk. Lenovo's published verification checks `db` for both `Windows UEFI CA 2023` and `Microsoft UEFI CA 2023`, plus `KEK` for `Microsoft Corporation KEK 2K CA 2023`. Verify script mirrors that pattern.
   - **Dell** — committed to BIOS updates for all sustaining platforms by end of 2025. New platforms since late 2024 ship with both 2011 and 2023 certs. SupportAssist OSRI USB and BIOSConnect break post-migration. Test before rolling.
   - **HP / ASUS** — minimal guidance from vendor. Test per-model.
6. **Intune Error 65000 on Win10/11 Pro** — was an MS bug, fixed Jan 27 2026. CSP was Enterprise-only by mistake.
7. **Hotpatch hosts on Win11 24H2** — reboot less, so the multi-reboot state machine stalls at Stage 4 for weeks. Expected.

## Style guide for any updates

Fleet "no fluff, no fear" style:

- Short, declarative sentences. Active voice.
- Sentence case headings. No title case.
- No em dashes — replace with commas, colons, or new sentences.
- Banned words: very, really, actually, basically, essentially, just, powerful, seamless, revolutionary, game-changing.
- Use "hosts" not "endpoints" or "agents".
- Use "BitLocker" only for Windows BitLocker contexts; "disk encryption" generally.
- Copy-ready outputs over explanatory prose.
- Don't add comments that restate the code. Add comments that explain *why* a non-obvious choice was made.

PowerShell specifics:

- `$ErrorActionPreference = 'Stop'` for scripts that mutate (migrate). `'Continue'` for read-only (verify).
- Empty catch blocks are not allowed. Always surface `$_.Exception.Message`.
- Use `$null -ne $var` not `if ($var)` for value checks — `0` is falsey in PowerShell.
- Use `-TaskPath` and `-TaskName` as separate parameters. Never pass a fully qualified task path in `-TaskName`.
- Structured key:value output via the `Write-State` helper. Width 30 for migrate, 32 for verify (existing convention).

osquery / SQL specifics:

- Drive reports from an expected set with `LEFT JOIN authenticode`, not from `authenticode` directly. Missing files must produce rows.
- Use `IFNULL(..., '0')` defensively on registry sub-queries.
- Backslashes in paths are literal in osquery's SQLite — no escaping needed.

## What's been tested

| Item | Status |
|------|--------|
| Report query against dogfood | ✅ Returned 3 distinct states across 4/5 responding hosts |
| Single-pass file inspection logic | ✅ Lint-checked, no empty catches, no boolean coercion |
| `-TaskPath` / `-TaskName` split | ✅ Matches Microsoft's documented API |
| Migrate script against a real `not_started` host | ❌ Not yet — primary next step |
| Verify script against a `compliant_via_registry` host | ❌ Not yet — confirms firmware/ESP hypothesis |
| Behaviour on Server 2019/2022 | ❌ Unknown — Server doesn't auto-migrate but should respond to manual trigger |
| Behaviour on Hotpatch (24H2) hosts | ❌ Unknown — state machine known to stall |

## Related upstream work

- **fleetdm/fleet#45474** — CSA pattern issue. Has dogfood test results table.
- **fleetdm/fleet#45510** — Upstream PR adding these to Fleet's `it-and-security/lib/windows/`. Different path layout than this repo. Two rounds of CodeRabbit review applied. Awaiting human review from `@allenhouchins`.
- **fleetdm/fleet#42318** — Open Fleet bug. Fleet sends `ConfigurePINUsageDropDown_Name = 2` (Allow) instead of `1` (Require). Blocks BitLocker TPM+PIN as defence-in-depth. PR #43915 has the fix.

CVE / KB references:
- **CVE-2023-24932** -- https://msrc.microsoft.com/update-guide/vulnerability/CVE-2023-24932
- **CVE-2025-48804 (BitUnlocker)** -- https://msrc.microsoft.com/update-guide/vulnerability/CVE-2025-48804
- **CVE-2026-45585 (YellowKey)** -- https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585
- **KB5025885** -- https://support.microsoft.com/en-us/topic/41a975df-beb2-40c1-99a3-b3ff139f832d
- **MS Secure Boot Playbook (client, Feb 2026)** -- https://techcommunity.microsoft.com/blog/windows-itpro-blog/secure-boot-playbook-for-certificates-expiring-in-2026/4469235
- **MS Windows Server Secure Boot Playbook (2026)** -- https://techcommunity.microsoft.com/blog/windowsservernewsandbestpractices/windows-server-secure-boot-playbook-for-certificates-expiring-in-2026/4495789
- **Eclypsium YellowKey analysis** -- https://eclypsium.com/blog/yellowkey-bitlocker-bypass-windows-recovery-environment/

## Adjacent BitLocker bypass threats

Out of scope for this migration but tracked here so the trust-chain context stays joined up:

- **YellowKey (CVE-2026-45585, disclosed May 12 2026).** Abuses `autofstx.exe` inside WinRE. autofstx replays NTFS transaction logs from any attached volume's `System Volume Information\FsTx` folder, deletes `winpeshl.ini`, and drops the attacker into `cmd.exe` with the BitLocker volume already unlocked. Affects Windows 11 and Server 2022/2025. Windows 10 is not affected. Microsoft published a mitigation on May 19 2026, with a deployable script on May 21. No full patch as of May 22 2026. The mitigation removes `autofstx.exe` from the WinRE image's Session Manager `BootExecute` value so the vulnerable replay never runs. `reagentc /disable` stays in the toolkit as a heavier escalation that closes the path by removing WinRE entirely. **TPM + PIN blocks the published PoC** but not the researcher's withheld TPM+PIN variant: treat TPM + PIN as raising attacker cost, not as a full mitigation. USB-block group policies and BIOS USB-boot blocks do **not** mitigate because WinRE does not honour OS-level USB policy and the attack does not boot from the stick.
- **BitUnlocker (CVE-2025-48804)** is mitigated by the CA 2023 migration this repo ships. TPM + PIN also defeats it independently because the TPM will not unseal the VMK without the PIN. Two independent paths to closure.
- **Intune policy gap (Fleet PR #43915, still open against upstream).** Intune currently sends `ConfigurePINUsageDropDown_Name = 2` (Allow) instead of `1` (Require), so TPM + PIN cannot be enforced via Intune today. Until the PR lands, TPM + PIN enforcement needs a custom CSP profile or scripted BCD configuration.
- **Stacked controls for hosts that handle sensitive data:** complete the CA 2023 migration (this repo), enforce TPM + PIN where feasible, strip `autofstx` from WinRE (run `mitigate-windows-yellowkey.ps1`), and `reagentc /disable` if WinRE is not needed locally. Each control closes a different attack path or raises attacker cost.

## YellowKey mitigation pattern in this repo

Same shape as the CA 2023 trio: detect, mitigate, verify. The mitigation
is Microsoft's `autofstx` strip from WinRE's Session Manager
`BootExecute`. `mitigate-windows-yellowkey.ps1` is a Fleet-flavored
adaptation of the reference script Microsoft publishes inside the
[CVE-2026-45585 MSRC advisory](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585)
FAQ ("Is there a script that I can copy and paste to implement a
mitigation?"). The Fleet wrapper adds a success marker, granular exit
codes, and structured `key:value` output. There is no opt-in gate
because Microsoft's autofstx strip is safe to apply on every affected
host.

| File | Purpose |
|------|---------|
| `windows-yellowkey.reports.yml` | Daily Fleet report on OS + BitLocker + WinRE state per host. Surfaces who is exposed, mitigated, or unaffected. Uses native osquery tables plus the snapshot file via `file_lines` (freshness-gated). |
| `verify-windows-yellowkey.ps1` | Read-only per-host inspection: WinRE state, BitLocker key protectors, success marker state. |
| `mitigate-windows-yellowkey.ps1` | Strips `autofstx.exe` from WinRE's `BootExecute` via `reagentc /mountre` + offline registry edit. Walks active ControlSets via the `Select` key. Re-seals with `reagentc /disable` + `/enable`. Runs unconditionally on affected hosts. |
| `snapshot-windows-yellowkey.ps1` | Captures WinRE state, BitLocker key protectors, success marker, and a freshness timestamp. |
| `cleanup-windows-yellowkey-snapshot.ps1` | Deletes the state file to force native-only fallback. |

**Success marker:**

```
HKLM\SOFTWARE\Fleet\YellowKey\BootExecMitigated  = 1 (DWORD)  // mitigate wrote this on success
```

`BootExecMitigated` is set by `mitigate-windows-yellowkey.ps1` only
when the edit loop completed without exception AND every ControlSet
was verified clean via read-back. The report reads it via osquery's
native `registry` table to surface the `mitigated` verdict regardless
of snapshot freshness.

The mitigation is one-way. If a patch ships, the patch supersedes the
strip. If a host genuinely needs `autofstx` back, restore manually and
clear `BootExecMitigated` from the same key.

**Why the autofstx strip, not `reagentc /disable`, as the default:**

- It is Microsoft's published, supported mitigation.
- Push-button reset, the in-WinRE BitLocker recovery flow, System
  Restore from boot, and Recovery Drive restore all keep working.

**When to escalate to `reagentc /disable`:**

- Hosts where WinRE is unnecessary by design (servers, kiosks, hosts
  with off-host imaging).
- Hosts in a threat model where any local recovery flow is itself an
  attack surface (high-sensitivity laptops with off-host imaging).
- Run `reagentc /disable` manually after the autofstx strip has been
  validated. The two mitigations stack and the report verdict moves
  to `mitigated_winre_off` (the heavier state takes precedence) once
  the snapshot is refreshed.

**Trade-offs of disabling WinRE (escalation only):**

- Push-button reset stops working (`Settings > Recovery > Reset this PC`).
- BitLocker recovery flow inside WinRE is gone. Recovery key is still
  honoured at the boot manager, but the WinRE-driven flow is not.
- System Restore from boot and Recovery Drive image restore are gone.
- Re-enable with `reagentc /enable` before any of these operations is
  needed.

**Script exit codes (`mitigate-windows-yellowkey.ps1`):**

| Code | Meaning |
|------|---------|
| 0 | autofstx removed, already absent, or WinRE already disabled |
| 2 | Opt-in marker missing; no action taken |
| 3 | OS not affected (Windows 10 etc.); no action taken |
| 4 | Mount, edit, unmount, or re-seal failed; manual investigation needed |

**Verify script:** always exits 0 unless PowerShell errors. Output is
the deliverable. Does not mount winre.wim; re-run mitigate (idempotent)
for ground truth on the offline image's `BootExecute` value.

## Open items

1. Run `verify-windows-ca-2023.ps1` on a `compliant_via_registry` host to confirm the ESP/firmware DB hypothesis.
2. Run `migrate-windows-ca-2023.ps1` against a `not_started` host. Expect preflight failure (exit 2/3) on a host without CU, or migration triggered (exit 0).
3. Re-run report after migration to confirm state transitions cleanly.
4. Run `snapshot-windows-ca-2023.ps1` and `snapshot-windows-yellowkey.ps1` on test hosts and confirm the freshness columns populate. Verify that letting a snapshot age past 48 hours flips `snapshot_status` to `stale` and falls back to native-only verdicts.
5. Run `mitigate-windows-yellowkey.ps1` against a test host. Confirm the report verdict moves from `exposed` to `mitigated`.
6. Decide whether to add a compliance policy in this repo (separate from the diagnostic report). Verdict logic should be settled before policy is shipped. Keep the policy `run_script` slot reserved for the actual remediation.
7. Optional follow-up: ship a scheduled-task installer for the snapshot scripts so freshness is automatic per host.
8. Test on Server 2019/2022.
9. Consider follow-up: a teardown script that re-runs `Set-ItemProperty AvailableUpdates 0x5944` if a host gets stuck mid-migration after CU update.

## Working with Claude Code

When making changes:

- Read this file before editing the scripts.
- Run the lint checks at the bottom of this section before committing.
- Verdict logic in the report YAML mirrors the decision tree in `migrate-windows-ca-2023.ps1`. Update both together if you change one.
- Keep `interval: 86400` (daily snapshot). Faster intervals hammer osquery for no gain — registry state doesn't change minute-to-minute.

Quick lint check from repo root:

```bash
for f in *.ps1; do
  echo "=== $f ==="
  grep -n 'catch *{ *}' "$f" && echo "  empty catch found" || echo "  ok: no empty catches"
  grep -nE 'if \(\$[a-zA-Z]+(Status|Error|Capable|Available)\)' "$f" && echo "  boolean coercion" || echo "  ok: explicit null"
  grep -n 'Start-ScheduledTask.*-TaskName.*\\Microsoft' "$f" && echo "  qualified path in TaskName" || echo "  ok: TaskPath/TaskName split"
done
```

PowerShell linting (if `Invoke-ScriptAnalyzer` available):

```bash
pwsh -c "Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning"
```
