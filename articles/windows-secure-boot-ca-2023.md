Detect and remediate the Windows Secure Boot CA 2023 migration with Fleet
=========================================================================

The Microsoft Windows Production PCA 2011 cert expires in October 2026. Anything still chained to it stops receiving Secure Boot servicing after that. The migration to the Windows UEFI CA 2023 is also the only closure for two BitLocker-adjacent vulnerabilities that depend on PCA 2011 staying trusted:

- **BlackLotus ([CVE-2023-24932](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2023-24932))** is a bootkit that swaps `bootmgfw.efi` for a vulnerable version still signed by PCA 2011 and bypasses BitLocker at the next boot.
- **BitUnlocker ([CVE-2025-48804](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2025-48804))** is a downgrade attack: an attacker with brief physical access drops a pre-July-2025 boot manager onto the ESP, firmware trusts it because PCA 2011 is still in DB, and the TPM-only BitLocker volume decrypts in under five minutes.

[KB5025885](https://support.microsoft.com/en-us/topic/41a975df-beb2-40c1-99a3-b3ff139f832d) ships the fix as one coordinated move: add Windows UEFI CA 2023 to the firmware DB, update the boot manager, revoke PCA 2011 in DBX. Patching alone is not enough; the DBX revocation step is what closes BlackLotus and BitUnlocker. Windows Server does not auto-migrate. Even on auto-rolling clients the migration runs in a multi-reboot state machine and customers want visibility.

This guide is the pattern, the drop-in scripts and report, and the operational notes you'll want before pointing it at a real fleet.

> **See also:** [Detect and mitigate the YellowKey BitLocker bypass with Fleet](windows-yellowkey-mitigation.md). YellowKey is a separate, unpatched WinRE vulnerability with its own response pattern.

How it works
------------

Three pieces:

1. A **report** (`windows-ca-2023.reports.yml`) queries the `authenticode` and `registry` osquery tables for per-host migration state and emits a `compliance_verdict` column. Native tables only. Daily snapshot.
2. A **migrate script** (`migrate-windows-ca-2023.ps1`) sets the `AvailableUpdates = 0x5944` trigger and starts the `\Microsoft\Windows\PI\Secure-Boot-Update` scheduled task. Idempotent. Conservative.
3. A **verify script** (`verify-windows-ca-2023.ps1`) does deep, read-only firmware-level inspection for one host at a time. It reads the firmware DB, KEK, DBX, and ESP boot manager signature directly, none of which osquery can reach.

Two signal layers
-----------------

The migration runs in two layers that drift apart for hours-to-days after completion:

| Layer | What it is | Where to look |
|-------|------------|---------------|
| **OS-side staging** | `C:\Windows\Boot\EFI\bootmgfw.efi` and friends, copied to ESP at the next servicing pass | osquery `authenticode` table |
| **Registry state machine** | Microsoft's own per-host servicing status | `HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing` keys, osquery `registry` table |

The report combines both:

```
compliance_verdict:
  compliant_via_files     OS-side file signed by CA 2023
  compliant_via_registry  registry says servicing finished
  in_progress             servicing in flight
  errored                 UEFICA2023Error != 0
  not_started             no other signals
```

File signatures alone produce false negatives: a host can be fully migrated at firmware level while the OS-side `bootmgfw.efi` still shows PCA 2011, because Windows Update refreshes the staging copy on its own cycle. The registry servicing state is the authoritative answer for "has firmware migrated." For hosts the report flags `compliant_via_registry`, run `verify-windows-ca-2023.ps1` to read the firmware DB and ESP boot manager directly.

Drop-in
-------

Pin the trio in `fleets/workstations.yml`:

```
controls:
  scripts:
    - path: ../lib/windows/scripts/migrate-windows-ca-2023.ps1
    - path: ../lib/windows/scripts/verify-windows-ca-2023.ps1
reports:
  - path: ../lib/windows/reports/windows-ca-2023.reports.yml
```

Run the report. Hosts in `not_started` are the migration candidates. `compliant_via_registry` hosts are firmware-migrated; verify on demand if you want firmware-level confirmation.

Trigger
-------

The migrate script sets one registry value and kicks one task:

```
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\Secureboot `
  -Name AvailableUpdates -Value 0x5944 -Type DWord
Start-ScheduledTask -TaskPath '\Microsoft\Windows\PI\' -TaskName 'Secure-Boot-Update'
```

`0x5944` is Microsoft's all-in-one bitmask. It installs CA 2023 in the DB, updates the boot manager, revokes PCA 2011 in DBX, and applies the SVN update. Microsoft documents granular values for staged rollouts but `0x5944` is the only one KB5025885 recommends for fleet-wide deployment.

| Value | Mitigation step |
|-------|-----------------|
| `0x140` | Install CA 2023 in DB + update boot manager |
| `0x80`  | Add PCA 2011 to DBX |
| `0x200` | Apply SVN update |
| `0x280` | DBX + SVN combined |
| `0x5944` | Full migration (recommended) |

Microsoft clears `AvailableUpdates` to 0 once the task picks it up. The script is idempotent; safe to re-run after each reboot until the registry servicing state shows `Updated`.

Banner phases
-------------

Three 2011-era certs expire in 2026:

| Cert | Expires |
|------|---------|
| Microsoft UEFI CA 2011 (third-party loaders) | June 2026 |
| Microsoft Windows Production PCA 2011 (Windows boot signing) | October 2026 |
| Microsoft Corporation KEK CA 2011 (Key Exchange Key) | October 19 2026 |

User-visible enforcement is already underway:

| Phase | Start | Behaviour |
|-------|-------|-----------|
| Initial | May 13 2026 (Win10), May 16 2026 (Win11) | Yellow advisory banner in Windows Security app |
| Intermediate | Q3 2026 | Orange banner plus full-screen notifications |
| Enforcement | October 2026 | KEK 2011 expires; non-migrated hosts lose Secure Boot servicing |

The yellow banner is live. End-users see it. The fix is the migration above. Plan rollout backwards from October.

OEM rollout
-----------

- **Lenovo.** CA 2023 plus KEK 2K CA 2023 already in firmware fleet-wide. Lowest risk.
- **Dell.** Committed to BIOS updates for all sustaining platforms by end of 2025. New platforms since late 2024 ship with both 2011 and 2023 certs. SupportAssist OSRI USB and BIOSConnect break post-migration; test before rolling.
- **HP.** Commercial PCs released 2022-2023 received BIOS updates around September 2025. 2019-2021 platforms around December 2025.
- **ASUS.** Phased Secure Boot database update rolling out since 2024.
- **Pre-2018 platforms.** Some never receive firmware updates. Treat as a separate cohort and document the residual risk.

See [Microsoft's Windows Server playbook](https://techcommunity.microsoft.com/blog/windowsservernewsandbestpractices/windows-server-secure-boot-playbook-for-certificates-expiring-in-2026/4495789) for server-side specifics. Server does not auto-migrate; trigger by hand. Generation 2 Hyper-V and VMware guests follow guest-OS update paths. Windows Server 2025 ships with the 2023 certs in firmware already.

Operational notes
-----------------

*   **Verify is the firmware-level tool.** Run `verify-windows-ca-2023.ps1` on hosts the report flags `compliant_via_registry` to read the firmware DB, KEK, DBX, and ESP boot manager signature directly. osquery cannot reach those signals.
*   **Servicing state and file signatures drift.** Expect `Updated` registry state with PCA 2011 file signatures for hours-to-days after migration completes. Not a bug. The OS-side staging copy of `bootmgfw.efi` gets refreshed on the next Windows Update cycle; the ESP copy (the one firmware loads) is on CA 2023 already.
*   **Recovery media breaks after DBX revocation.** Rebuild WinRE and install media against CA 2023 sources before pushing migration broadly. Recovery USBs created before migration won't boot afterward.
*   **Hotpatch hosts stall at Stage 4.** Windows 11 24H2 Hotpatch hosts reboot less often, so the multi-reboot state machine stalls. Expected. Force a non-hotpatch update cycle to advance.
*   **PCA 2011 expiry is October, not June.** June 2026 is the third-party `Microsoft UEFI CA 2011`. The Windows boot-signing PCA 2011 expires in October.
*   **Errored state.** `UEFICA2023Error != 0` means the migration failed mid-flight. The migrate script bails on this rather than retrying. Check Event Viewer > System for IDs 1036, 1037, 1795, 1799, 1801, 1803 to diagnose.

Wrap-up
-------

One migration, three problems closed: BlackLotus, BitUnlocker, and the October 2026 servicing cliff. The pattern is a native-osquery report for fleet-wide visibility, a focused PowerShell verify script for firmware-level diagnosis, and idempotent remediation that respects Microsoft's multi-reboot state machine. Pin the files via your fleets YAML, label-target the hosts you want covered, and let the report tell you who's still behind.
