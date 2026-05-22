Detect and remediate Windows BitLocker and Secure Boot threats with Fleet
=========================================================================

Three Windows boot-path threats matter for the next eight months and one
GitOps repo handles them with the same shape.

- **YellowKey ([CVE-2026-45585](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585))** abuses WinRE's `autofstx.exe` to drop into a shell with the BitLocker volume unlocked. Disclosed May 12 2026, Microsoft mitigation published May 19, no full patch yet.
- **BlackLotus ([CVE-2023-24932](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2023-24932))** and **BitUnlocker ([CVE-2025-48804](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2025-48804))** are a bootkit and a downgrade attack against the Secure Boot chain. Both depend on Microsoft's 2011 boot CA staying trusted. Both close when [KB5025885](https://support.microsoft.com/en-us/topic/41a975df-beb2-40c1-99a3-b3ff139f832d) migrates the host to the Windows UEFI CA 2023 and revokes the 2011 cert in DBX.
- **PCA 2011 expiry** and **KEK CA 2011 expiry** arrive in October 2026. Hosts still chained to the 2011 certs stop receiving Secure Boot servicing. The same KB5025885 migration is the fix.

One detect, mitigate, verify shape covers all three. Drop the files into a GitOps repo, point a fleet at them, and you get per-host visibility plus idempotent remediation that survives Microsoft's multi-reboot state machines.

How it works
------------

Three pieces per threat:

1. **A report** (`*.reports.yml`) queries osquery for per-host state and emits a verdict column. Daily snapshot.
2. **A snapshot script** (`snapshot-windows-*.ps1`) captures signals osquery can't reach: firmware DB contents, WinRE state, BitLocker key protectors, Fleet registry markers. Writes `key=value` lines to a state file the report `LEFT JOIN`s.
3. **A migrate or mitigate script** (`migrate-windows-*.ps1`, `mitigate-windows-*.ps1`) applies the remediation. Idempotent. Respects in-flight workflows. Bails on prereq failures rather than retrying blindly.

A **verify script** (`verify-windows-*.ps1`) does deep, read-only inspection for one host at a time and is used to confirm what the report says.

The reports never need the snapshot file to function. Without it, snapshot-derived columns read `run snapshot script` and the verdict falls back to the safe default. Snapshot refresh is opt-in via [Fleet > Controls > Scripts](https://fleetdm.com/docs/using-fleet/scripts); Fleet policies cap `run_script` retries at 3, so daily-refresh use cases burn through the cap fast. Keep the policy `run_script` slot for the real remediation.

Stack 1: Secure Boot CA 2023 migration
--------------------------------------

KB5025885 ships the fix as a single coordinated move:

- Add the **Windows UEFI CA 2023** to the firmware DB.
- Update the boot manager on the EFI System Partition (ESP) to one signed by CA 2023.
- Add the **Microsoft Windows Production PCA 2011** cert to the DBX so the old boot manager stops being trusted.
- Apply an SVN update to the firmware.

Trigger the lot with `AvailableUpdates = 0x5944` in `HKLM\SYSTEM\CurrentControlSet\Control\Secureboot`, then kick the `\Microsoft\Windows\PI\Secure-Boot-Update` scheduled task. The migration runs in a multi-reboot state machine. Sometimes two reboots, sometimes more.

The repo's `migrate-windows-ca-2023.ps1` is idempotent and conservative: skips if all three boot binaries are already signed by CA 2023, leaves in-progress workflows alone, bails on `UEFICA2023Error != 0` rather than retrying. Drop it into a label-targeted Fleet script and re-run after each reboot.

`verify-windows-ca-2023.ps1` reads the firmware DB, KEK, DBX, and ESP boot manager signature directly. osquery has no EFI-variable table so this is the only way to ground-truth a host that the report marks `compliant_via_registry`.

The report verdicts:

```
compliance_verdict:
  compliant_via_files           OS-side file signed by CA 2023
  compliant_via_firmware        ESP boot manager signed by CA 2023 (snapshot)
  compliant_via_registry        registry says servicing finished
  in_progress                   servicing in flight
  errored                       UEFICA2023Error != 0
  not_started_ready_to_trigger  firmware DB has CA 2023, never triggered
  not_started_cu_missing        firmware DB lacks CA 2023, no CU yet
  not_started                   no other signals (run snapshot for refinement)
```

Pin the trio in `fleets/workstations.yml`:

```
controls:
  scripts:
    - path: ../lib/windows/scripts/migrate-windows-ca-2023.ps1
    - path: ../lib/windows/scripts/verify-windows-ca-2023.ps1
    - path: ../lib/windows/scripts/snapshot-windows-ca-2023.ps1
reports:
  - path: ../lib/windows/reports/windows-ca-2023.reports.yml
```

Windows Server doesn't auto-migrate via Microsoft's Controlled Feature Rollout. Trigger the same `0x5944` value by hand on Server hosts. Generation 2 Hyper-V and VMware guests follow guest-OS update paths, not host firmware. Windows Server 2025 ships with the 2023 certs in firmware already. See [Microsoft's Windows Server playbook](https://techcommunity.microsoft.com/blog/windowsservernewsandbestpractices/windows-server-secure-boot-playbook-for-certificates-expiring-in-2026/4495789) for the server-side specifics.

Stack 2: YellowKey
------------------

CVE-2026-45585 lives in WinRE's `autofstx.exe`. autofstx replays NTFS transaction logs from any attached volume's `System Volume Information\FsTx` folder, deletes `winpeshl.ini`, and drops the attacker into `cmd.exe` with the BitLocker volume already unlocked. Affects Windows 11, Server 2022, Server 2025. Windows 10 ships a different WinRE component and isn't affected.

Microsoft's mitigation: remove the `autofstx.exe` entry from the WinRE image's Session Manager `BootExecute` value. The vulnerable replay never runs and recovery flows keep working. Microsoft publishes the canonical PowerShell script inside the [CVE-2026-45585 MSRC advisory](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585) FAQ, under *"Is there a script that I can copy and paste to implement a mitigation?"*.

The repo's `mitigate-windows-yellowkey.ps1` is a Fleet-flavored adaptation of that reference script. The MS core stays intact:

1. `reagentc /mountre /path` to mount the WinRE image.
2. `reg load` the offline SYSTEM hive.
3. Walk active ControlSets via `\Select\Current` and `\Select\Default`, strip `autofstx.exe` from `BootExecute` in each.
4. `reg unload` (with retry).
5. `reagentc /unmountre /commit`.
6. `reagentc /disable` + `/enable` to re-seal the BitLocker measurement chain.

Fleet adds:

- Refuses to act without `HKLM\SOFTWARE\Fleet\YellowKey\AllowMitigation = 1`. Editing the WinRE image is a deliberate, label-scoped action.
- Skips silently if WinRE is already disabled (a stronger mitigation is already in place).
- Writes `HKLM\SOFTWARE\Fleet\YellowKey\BootExecMitigated = 1` on success so the snapshot can surface the mitigated state without re-mounting the WIM.
- Granular exit codes for Fleet reporting.

Idempotent and one-way. If a patch ships, the patch supersedes the strip; there's no unmitigate counterpart.

Set the opt-in marker against a labelled subset:

```
# Fleet > Controls > Scripts
set-yellowkey-allow-mitigation.ps1     # against label `yellowkey-mitigate-ok`
mitigate-windows-yellowkey.ps1         # same label
```

Pin the YellowKey files in the same `fleets/workstations.yml`:

```
controls:
  scripts:
    - path: ../lib/windows/scripts/set-yellowkey-allow-mitigation.ps1
    - path: ../lib/windows/scripts/mitigate-windows-yellowkey.ps1
    - path: ../lib/windows/scripts/verify-windows-yellowkey.ps1
    - path: ../lib/windows/scripts/snapshot-windows-yellowkey.ps1
reports:
  - path: ../lib/windows/reports/windows-yellowkey.reports.yml
```

TPM + PIN blocks the published PoC but **not** the researcher's withheld TPM+PIN variant. Treat TPM + PIN as raising attacker cost, not as a full mitigation.

`reagentc /disable` remains in the toolkit as a heavier escalation for hosts where WinRE is unnecessary by design (servers, kiosks, off-host imaging). Run it manually after the autofstx strip has been validated. The two mitigations stack and the report verdict moves to `mitigated_winre_off`.

The report verdicts:

```
yellowkey_exposure_verdict:
  not_affected                 Windows 10
  mitigated_bootexec_stripped  autofstx removed from WinRE BootExecute
  mitigated_winre_off          WinRE disabled (heavier control)
  not_exposed_bitlocker_off    WinRE on, BitLocker not protecting
  exposed                      WinRE on + BitLocker protecting + no Fleet mitigation marker
  affected_if_winre_on         snapshot missing (run snapshot script)
  unknown                      unrecognised OS
```

Stack 3: October 2026 cert expiry
----------------------------------

Three 2011-era certs expire in 2026, in two stages:

| Cert | Expires | Effect |
|------|---------|--------|
| Microsoft UEFI CA 2011 (third-party loaders) | June 2026 | Linux shims signed only under 2011 stop being trusted |
| Microsoft Windows Production PCA 2011 (boot signing) | October 2026 | Hosts still chained to 2011 stop receiving Secure Boot servicing |
| Microsoft Corporation KEK CA 2011 (Key Exchange Key) | October 19 2026 | Same |

User-visible enforcement is staggered:

| Phase | Start | Behaviour |
|-------|-------|-----------|
| Initial | May 13 2026 (Win10), May 16 2026 (Win11) | Yellow advisory banner in Windows Security app |
| Intermediate | Q3 2026 | Orange banner plus full-screen notifications |
| Enforcement | October 2026 | KEK 2011 expires; non-migrated hosts lose Secure Boot servicing |

The yellow banner is live on Win10 (since May 13) and Win11 (since May 16) hosts. Customers see it. The fix is the same `migrate-windows-ca-2023.ps1` from Stack 1. Plan rollout backwards from October 2026.

OEM rollout status as of May 2026:

- **Lenovo.** CA 2023 + KEK 2K CA 2023 already in firmware fleet-wide. Lowest risk.
- **Dell.** Committed to BIOS updates for all sustaining platforms by end of 2025. New platforms since late 2024 ship with both 2011 and 2023 certs. SupportAssist OSRI USB and BIOSConnect break post-migration; test before rolling.
- **HP.** Commercial PCs released 2022-2023 received BIOS updates around September 2025. 2019-2021 platforms around December 2025.
- **ASUS.** Phased Secure Boot database update rolling out since 2024.
- **Pre-2018 platforms.** Some never receive firmware updates. Treat as a separate cohort and document the residual risk.

Operational notes
-----------------

*   **Snapshot file lifecycle.** Snapshots live at `C:\ProgramData\Fleet\state\windows-*-snapshot.txt`. They're optional. Without them, the reports still work; the snapshot-derived columns show `run snapshot script` and verdicts fall back to safe defaults. Use `cleanup-windows-snapshots.ps1` to test the cold-import path.
*   **Servicing state and file signatures drift.** Expect `Updated` registry state with PCA 2011 file signatures for hours-to-days after CA 2023 migration completes. Not a bug. The OS-side staging copy of `bootmgfw.efi` gets refreshed on the next Windows Update cycle; the ESP copy (the one firmware loads) is on CA 2023 already.
*   **Recovery media breaks after DBX revocation.** Rebuild WinRE and install media against CA 2023 sources before pushing migration broadly. Recovery USBs created before migration won't boot afterward.
*   **Hotpatch hosts stall at Stage 4.** Windows 11 24H2 Hotpatch hosts reboot less often, so the CA 2023 multi-reboot state machine stalls. Expected. Force a non-hotpatch update cycle to advance.
*   **Don't trust TPM-only.** YellowKey is one of two recent BitLocker bypasses against TPM-only configurations. Move high-risk hosts to TPM + PIN where the threat model includes physical access, even though TPM + PIN doesn't block YellowKey's withheld variant.
*   **The CA 2023 migration closes BlackLotus and BitUnlocker simultaneously.** Both depend on PCA 2011 staying trusted. DBX revocation closes both. One migration, two CVEs.
*   **PCA 2011 expiry is October 2026, not June 2026.** June 2026 is the third-party `Microsoft UEFI CA 2011`. The Windows boot-signing PCA 2011 expires in October.

Wrap-up
-------

Three threats, one pattern: snapshot signals osquery can't reach, report verdicts that work with or without the snapshot, idempotent remediation that respects Microsoft's state machines. The CA 2023 migration closes BlackLotus, BitUnlocker, and the October 2026 servicing cliff in one move. The YellowKey `autofstx` strip closes CVE-2026-45585 without losing recovery flows. Both run as Fleet scripts, both are reversible, both surface their state in a daily report.

Pin the files via your fleets YAML, label-target the hosts you want covered, and let the report tell you who's still behind.
