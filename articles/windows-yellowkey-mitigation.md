Detect and mitigate the YellowKey BitLocker bypass with Fleet
=============================================================

[YellowKey (CVE-2026-45585)](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585) is an unpatched BitLocker bypass on Windows 11, Server 2022, and Server 2025. Microsoft shipped a mitigation on May 19 2026; there is no full patch yet. This pattern gives you an osquery extension that flags exposed hosts live, a daily report over it, a policy that keeps the extension installed, and a script that applies Microsoft's mitigation.

The threat
----------

YellowKey abuses `autofstx.exe` in the Windows Recovery Environment. With brief physical access, an attacker drops a crafted `FsTx` blob on a USB stick or the EFI System Partition and reboots into WinRE. autofstx replays NTFS transaction logs that delete `winpeshl.ini`, so WinRE falls back to `cmd.exe` with the BitLocker volume unlocked. Windows 10 ships a different WinRE component and is not affected.

USB-block GPOs and BIOS USB-boot blocks do not stop it: WinRE ignores OS USB policy, and the attack does not boot from the stick. TPM-only BitLocker is the target, not a defense. What works is stripping `autofstx.exe` from WinRE's Session Manager `BootExecute`, which is Microsoft's mitigation and what this repo automates. TPM + PIN blocks the published PoC but not the researcher's withheld variant, so treat it as raising attacker cost.

What's in the repo
------------------

| File | Role |
|---|---|
| `extensions/windows_yellowkey/` | osquery extension; exposes the `windows_yellowkey` table |
| `lib/windows/reports/windows-yellowkey.reports.yml` | Daily per-host report |
| `lib/windows/policies/windows-yellowkey-extension.policies.yml` | Keeps the extension installed |
| `lib/windows/scripts/install-yellowkey-extension.ps1` | Installs and loads the extension |
| `lib/windows/scripts/mitigate-windows-yellowkey.ps1` | Applies Microsoft's mitigation |
| `.github/workflows/build-extensions.yml` | Builds and releases the extension binaries |

Detect
------

The extension reads OS, WinRE state, BitLocker key protectors, and the `BootExecMitigated` marker on every query, then returns one `state` per host. No snapshot file, no freshness gate. A host returns a row once the extension is loaded; the policy below installs it.

| state | Meaning |
|---|---|
| `not_affected` | Windows 10 |
| `mitigated` | autofstx stripped, marker set |
| `mitigated_winre_off` | WinRE disabled |
| `bitlocker_off` | no protected BitLocker volume |
| `exposed` | affected OS, BitLocker on, no mitigation |
| `unknown` | unrecognised OS |

The report is one line:

```
SELECT state, state_reason, needs_action, winre_enabled, tpm_only, mitigated FROM windows_yellowkey;
```

Mitigate
--------

`mitigate-windows-yellowkey.ps1` adapts [Microsoft's script](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585): mount the WinRE image with `reagentc /mountre`, load the offline SYSTEM hive, strip `autofstx` from every ControlSet's `BootExecute`, unmount with `/commit`, then `reagentc /disable` + `/enable` to re-seal the BitLocker measurement chain.

It verifies each ControlSet by read-back and writes `HKLM\SOFTWARE\Fleet\YellowKey\BootExecMitigated = 1` only when every one is clean. Exit codes: `0` done, `3` OS not affected, `4` failed. There is no opt-in gate, since Microsoft's strip is safe on every affected host, and no unmitigate: if a patch ships, apply it and clear the marker.

Deploy
------

The `windows-yellowkey-extension` policy checks `osquery_registry` for the `windows_yellowkey` table (`SELECT 1 FROM osquery_registry WHERE registry = 'table' AND name = 'windows_yellowkey' AND active = 1`). It passes when the extension is loaded and fails when it is not, with no error state. Querying the table directly would error when the extension is absent, which Fleet shows as neither pass nor fail and would not trigger the installer. Failing hosts run `install-yellowkey-extension.ps1`, which downloads the architecture-matching binary, places it under `C:\Program Files\Orbit\extensions\`, registers it in orbit's `extensions.load`, and restarts orbit.

Binaries come from a tag push. `.github/workflows/build-extensions.yml` builds every extension under `extensions/` and publishes the `.exe` files as release assets:

```
git tag v1.0.0
git push --tags
```

Roll it out
-----------

Pin everything in `fleets/workstations.yml`:

```
policies:
  - path: ../lib/windows/policies/windows-yellowkey-extension.policies.yml
reports:
  - path: ../lib/windows/reports/windows-yellowkey.reports.yml
controls:
  scripts:
    - path: ../lib/windows/scripts/install-yellowkey-extension.ps1
    - path: ../lib/windows/scripts/mitigate-windows-yellowkey.ps1
```

1. Apply: `fleetctl gitops -f fleets/workstations.yml`.
2. Cut a release: `git tag v1.0.0 && git push --tags`.
3. Hosts install the extension on their next check-in.
4. Open the report, then run `mitigate-windows-yellowkey.ps1` against `exposed` hosts via Fleet > Controls > Scripts.
5. Re-run the report. Those hosts move to `mitigated`.

Operational notes
-----------------

- Inspect one host with `SELECT * FROM windows_yellowkey`. If the extension will not load, `reagentc /info` and `Get-BitLockerVolume` give the same signals without osquery.
- `reagentc /disable` also removes push-button reset, in-WinRE BitLocker recovery, System Restore from boot, and Recovery Drive restore. Re-enable with `reagentc /enable` before you need them.
- Move high-risk hosts to TPM + PIN where the threat model includes physical access. It blocks the public PoC and raises attacker cost on the withheld variant.
