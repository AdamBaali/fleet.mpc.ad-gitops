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
| `.github/workflows/build-extensions.yml` | CI: builds every extension on change (optional versioned releases on a tag) |

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

The `windows-yellowkey-extension` policy checks `osquery_registry` for the `windows_yellowkey` table (`SELECT 1 FROM osquery_registry WHERE registry = 'table' AND name = 'windows_yellowkey' AND active = 1`). It passes when the extension is loaded and fails when it is not, with no error state. Querying the table directly would error when the extension is absent, which Fleet shows as neither pass nor fail and would not trigger the installer. Failing hosts run `install-yellowkey-extension.ps1`. It reads `PROCESSOR_ARCHITECTURE`, downloads the matching binary (`windows_yellowkey-amd64.exe` or `-arm64.exe`) from the repo, places it under `C:\Program Files\Orbit\extensions\`, and runs it as a LocalSystem scheduled task that connects to osquery's extension socket.

The binaries are committed under `extensions/windows_yellowkey/` and the installer pulls the arch-matching one from the repo's raw URL on `main`. No release or tag to cut. Rebuild with `make build` and commit when the extension changes.

orbit owns the autoload file. On every start it rewrites `C:\Program Files\Orbit\extensions.load` from the extension set Fleet sends it (delivered through a TUF update server) and only then hands osquery `--extensions_autoload`. With nothing configured there, orbit writes an empty file, so a path written into `extensions.load` by hand is wiped on the next orbit restart and the table never registers. Setting `extensions_autoload` in agent options does not help either: Fleet owns that flag and `fleetctl gitops` rejects it ("The --extensions_autoload flag isn't supported").

So the installer does not write `extensions.load`. An osquery extension is a process that connects to osquery's extension socket and registers its tables, and autoload is only one way to start it. The installer reads osquery's socket from the running osqueryd (orbit's default is the named pipe `\\.\pipe\orbit-osquery-extension`) and registers a LocalSystem scheduled task that runs the extension against it and reconnects whenever osquery restarts. The binary and its supervisor run as SYSTEM, so the installer hardens them and their directory to Administrators and SYSTEM only with inheritance removed, otherwise a non-admin could swap in code that runs as SYSTEM. For a catalog of extensions, Fleet's supported path is orbit's managed set on a self-hosted TUF update server (`fleetctl updates add` plus the global or team extension config); the scheduled-task approach scales by one task per extension and needs no update-server infrastructure.

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
2. Hosts install the extension on their next check-in (the policy runs the installer).
3. Open the report, then run `mitigate-windows-yellowkey.ps1` against `exposed` hosts via Fleet > Controls > Scripts.
4. Re-run the report. Those hosts move to `mitigated`.

If the table does not register
------------------------------

The policy stays failing when the extension is not connected to osquery. Check the host:

```
# 1. the supervisor task exists and is running
Get-ScheduledTask -TaskName 'Fleet windows_yellowkey extension' | Get-ScheduledTaskInfo

# 2. the extension process is up
Get-Process windows_yellowkey -ErrorAction SilentlyContinue

# 3. osquery is up for it to connect to
(Get-CimInstance Win32_Process -Filter "Name='osqueryd.exe'").CommandLine -match 'extensions_socket'
```

No task means the installer did not finish; re-run it. A task but no `windows_yellowkey` process means osquery was down when the task last tried, and it reconnects within a few seconds on its own. Do not write the binary into `extensions.load` and restart orbit: orbit rewrites that file empty on every start, so the entry is wiped and the table never registers. Re-running the installer re-creates the task and self-heals.

Operational notes
-----------------

- Inspect one host with `SELECT * FROM windows_yellowkey`. If the extension will not load, `reagentc /info` and `Get-BitLockerVolume` give the same signals without osquery.
- `reagentc /disable` also removes push-button reset, in-WinRE BitLocker recovery, System Restore from boot, and Recovery Drive restore. Re-enable with `reagentc /enable` before you need them.
- Move high-risk hosts to TPM + PIN where the threat model includes physical access. It blocks the public PoC and raises attacker cost on the withheld variant.
