Detect and mitigate the YellowKey BitLocker bypass with Fleet
=============================================================

[YellowKey (CVE-2026-45585)](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585) is an unpatched BitLocker bypass disclosed May 12 2026. An attacker with brief physical access to a Windows 11, Server 2022, or Server 2025 host can read everything on the encrypted drive. Microsoft published a mitigation on May 19 with a deployable script on May 21. No full patch yet.

This guide is the pattern, the drop-in scripts and report, and the operational notes you'll want before pointing it at a real fleet.

> **See also:** [Detect and remediate the Windows Secure Boot CA 2023 migration with Fleet](windows-secure-boot-ca-2023.md). Separate boot-chain problem with its own response pattern; also closes two other BitLocker-related CVEs.

What YellowKey does
-------------------

YellowKey abuses `autofstx.exe` inside the Windows Recovery Environment. autofstx is the FsTx auto-recovery utility; it runs early during WinRE boot and replays NTFS transaction logs from any attached volume's `System Volume Information\FsTx` folder.

The attack:

1. Drop a crafted `FsTx` blob on a USB stick or directly on the EFI System Partition.
2. Reboot into WinRE. Shift + Restart, or hold Ctrl during the recovery menu.
3. autofstx replays the transaction logs, which delete `winpeshl.ini`.
4. Without `winpeshl.ini`, WinRE falls back to spawning `cmd.exe` instead of the locked-down recovery UI.
5. The shell runs with the BitLocker volume already unlocked.

Affects Windows 11, Server 2022, Server 2025. Windows 10 ships a different WinRE component and isn't affected.

What doesn't mitigate it:

- USB-block group policies. WinRE doesn't honour OS-level USB policy.
- BIOS USB-boot blocks. The attack doesn't boot from the stick; it boots normally into WinRE.
- TPM-only BitLocker. The whole point of the bypass.

What does:

- Removing `autofstx.exe` from WinRE's Session Manager `BootExecute`. The vulnerable replay never runs. Microsoft's published mitigation.
- `reagentc /disable` to remove WinRE entirely. Heavier; loses push-button reset, in-WinRE BitLocker recovery, System Restore from boot.
- TPM + PIN blocks the published PoC. The researcher built a TPM+PIN variant but withheld it, so treat TPM + PIN as raising attacker cost, not as a full mitigation.

Microsoft's mitigation
----------------------

The canonical script is in the [CVE-2026-45585 MSRC advisory](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585) FAQ, under *"Is there a script that I can copy and paste to implement a mitigation?"*. Plain-English flow:

1. Mount the WinRE image with `reagentc /mountre /path`.
2. Load the offline `SYSTEM` hive into the live registry.
3. Walk the active ControlSets (`Current` and `Default` from `\Select`) and strip `autofstx.exe` from each `Control\Session Manager\BootExecute`.
4. Unload the hive.
5. `reagentc /unmountre /path /commit`.
6. `reagentc /disable` + `reagentc /enable` to re-seal the BitLocker measurement chain.

The Fleet wrapper
-----------------

The repo's `mitigate-windows-yellowkey.ps1` is a Fleet-flavored adaptation of Microsoft's reference script. The MS core stays intact: same mount commands, same multi-ControlSet walk, same re-seal cycle, same language-agnostic `Enabled` detection.

Fleet adds:

- **Opt-in marker.** Refuses to act without `HKLM\SOFTWARE\Fleet\YellowKey\AllowMitigation = 1`. Editing the WinRE image is a deliberate, label-scoped action; a misconfigured policy shouldn't mass-edit recovery images.
- **Success marker.** Writes `HKLM\SOFTWARE\Fleet\YellowKey\BootExecMitigated = 1` after a successful strip. The Fleet report reads this via osquery's native `registry` table to surface the `mitigated` verdict.
- **OS check.** Skips on Windows 10 (exit 3) and unrecognised SKUs.
- **WinRE-disabled detection.** Skips silently if WinRE is already off (exit 0); a stronger mitigation is already in place.
- **Granular exit codes.** 0 (success or already mitigated), 2 (marker missing), 3 (OS not affected), 4 (mount, edit, unmount, or re-seal failed).
- **Structured `key:value` output** for Fleet log capture.

One-way. There is no unmitigate counterpart. If a patch ships, the patch supersedes the strip. If a host genuinely needs `autofstx` back, restore manually and clear `BootExecMitigated` from the same key.

Drop-in
-------

Pin the YellowKey files in `fleets/workstations.yml`:

```
controls:
  scripts:
    - path: ../lib/windows/scripts/set-yellowkey-allow-mitigation.ps1
    - path: ../lib/windows/scripts/mitigate-windows-yellowkey.ps1
    - path: ../lib/windows/scripts/verify-windows-yellowkey.ps1
reports:
  - path: ../lib/windows/reports/windows-yellowkey.reports.yml
```

Workflow:

1. Run the report. Hosts marked `exposed` are the candidates.
2. For each host you want mitigated, run `set-yellowkey-allow-mitigation.ps1` to write the opt-in marker.
3. Run `mitigate-windows-yellowkey.ps1` against the same label. It mounts WinRE, strips autofstx, re-seals, and sets the `BootExecMitigated` success marker.
4. Re-run the report. Hosts move from `exposed` to `mitigated`.

Report verdicts (native osquery tables only):

```
yellowkey_exposure_verdict:
  not_affected   Windows 10
  mitigated      Fleet BootExecMitigated marker set (autofstx strip applied)
  bitlocker_off  BitLocker not protecting the volume
  exposed        BitLocker on + no mitigation marker (WinRE assumed on)
  unknown        unrecognised OS
```

WinRE enabled/disabled state is not reachable from native osquery tables. The report assumes WinRE is on for affected SKUs (the Microsoft default) and surfaces `exposed` accordingly. For per-host ground truth, run `verify-windows-yellowkey.ps1`; it reads `reagentc /info`, BitLocker key protector types, and both Fleet markers.

Escalation: `reagentc /disable`
------------------------------

Some hosts don't need WinRE: kiosks, servers, hosts with off-host imaging. For those, the heavier mitigation is `reagentc /disable`. It closes YellowKey by removing WinRE entirely.

Run `reagentc /disable` manually after the autofstx strip has been validated, against the subset of hosts where the trade-offs are acceptable:

- Push-button reset stops working.
- BitLocker recovery flow inside WinRE is gone. The recovery key is still honoured at the boot manager, but the WinRE-driven flow is gone.
- System Restore from boot and Recovery Drive image restore are gone.
- Re-enable with `reagentc /enable` before any of those operations is needed.

The two mitigations stack. The native-only report does not detect WinRE-off state, so hosts mitigated via the escalation still need the `BootExecMitigated` marker for the verdict to read `mitigated`. Run `verify-windows-yellowkey.ps1` for the full picture.

Operational notes
-----------------

*   **Verify is the per-host inspector.** `verify-windows-yellowkey.ps1` reads `reagentc /info`, BitLocker key protectors via `Get-BitLockerVolume`, and both Fleet markers. Use it to ground-truth report verdicts.
*   **The mitigate script needs admin.** It mounts the WinRE image and edits an offline registry hive. The Fleet wrapper checks `IsInRole(Administrator)` and exits 4 if not.
*   **`reagentc /mountre` will fail if the mount dir is dirty.** The script's default mount path is `C:\ProgramData\Fleet\state\yk-winre-mount`. It refuses to use a non-empty directory. Override with `-MountPath`.
*   **Multi-ControlSet hosts.** Failed-boot recovery hosts often run from `ControlSet002`. The mitigate script walks both `Current` and `Default` from the `\Select` key, matching Microsoft's reference.
*   **Re-seal is what keeps BitLocker happy.** After committing changes to the WIM, the script runs `reagentc /disable` + `reagentc /enable`. This refreshes WinRE's registration so the BitLocker measurement chain stays intact.
*   **When MS ships a patch.** Apply the patch and clear `BootExecMitigated` from the host registry. The mitigation marker doesn't auto-clear because the script is one-way; the report will keep showing `mitigated` until the marker is gone.
*   **Don't trust TPM-only.** YellowKey is one of two recent BitLocker bypasses against TPM-only configurations. Move high-risk hosts to TPM + PIN where the threat model includes physical access, even though TPM + PIN doesn't block YellowKey's withheld variant.

Wrap-up
-------

Microsoft published a clean mitigation; the Fleet wrapper adds opt-in safety, a success marker for the report, and Fleet-shaped exit codes. The mitigation is one-way: apply, the marker stays, the report keeps it visible. When the patch arrives the marker is the only thing left to clean up.
