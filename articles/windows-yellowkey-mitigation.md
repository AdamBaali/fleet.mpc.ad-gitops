Detect, mitigate, and verify the YellowKey BitLocker bypass with Fleet
======================================================================

[YellowKey (CVE-2026-45585)](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585) is an unpatched BitLocker bypass on Windows 11, Server 2022, and Server 2025. Microsoft published a mitigation on May 19 2026; no full patch yet. This guide is the Fleet-flavored detect-mitigate-verify pattern: a daily report that surfaces exposed hosts, a remediation script that applies Microsoft's mitigation safely on every affected host, and a policy that keeps the detection extension installed across the fleet.

> **See also:** [Detect and remediate the Windows Secure Boot CA 2023 migration with Fleet](windows-secure-boot-ca-2023.md). Separate boot-chain problem; same Fleet pattern.

The threat
----------

YellowKey abuses `autofstx.exe` inside the Windows Recovery Environment. An attacker with brief physical access drops a crafted `FsTx` blob on a USB stick or the EFI System Partition, reboots into WinRE, and `autofstx` replays NTFS transaction logs that delete `winpeshl.ini`. Without `winpeshl.ini`, WinRE spawns `cmd.exe` as a fallback, running with the BitLocker volume already unlocked.

Affects Windows 11, Server 2022, Server 2025. Windows 10 ships a different WinRE component and is not affected.

What does **not** mitigate it:

- USB-block GPOs and BIOS USB-boot blocks. WinRE does not honour OS-level USB policy, and the attack does not boot from the stick.
- TPM-only BitLocker. The whole point of the bypass.

What does:

- Strip `autofstx.exe` from WinRE's Session Manager `BootExecute`. Microsoft's [official mitigation](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585), and what this repo automates.
- `reagentc /disable`. Heavier; loses push-button reset and the in-WinRE BitLocker recovery flow.
- TPM + PIN blocks the published PoC. The researcher withheld a TPM+PIN variant, so treat PIN as raising attacker cost, not a full block.

What lands in your repo
-----------------------

| File | Role |
|---|---|
| `extensions/windows_yellowkey/` | Native osquery extension exposing the `windows_yellowkey` virtual table in real time |
| `lib/windows/reports/windows-yellowkey.reports.yml` | Daily report: queries the extension table for per-host state |
| `lib/windows/policies/windows-yellowkey-extension.policies.yml` | Policy that checks the extension is loaded; auto-runs the installer on failure |
| `lib/windows/scripts/install-yellowkey-extension.ps1` | Downloads the binary, registers it in orbit, restarts orbit to load it |
| `lib/windows/scripts/mitigate-windows-yellowkey.ps1` | Strips `autofstx.exe` from WinRE; safe to run on every affected host |
| `lib/windows/scripts/verify-windows-yellowkey.ps1` | Read-only per-host inspection (standalone, no osquery needed) |
| `.github/workflows/build-extensions.yml` | Tag-driven release: builds every extension and uploads `.exe` files |

Detect
------

The `windows_yellowkey` osquery extension does the work. On each query it reads the OS, WinRE state (`reagentc /info`), BitLocker key protectors (`Get-BitLockerVolume`), and the Fleet `BootExecMitigated` success marker, then derives a single `state` verdict. No snapshot file, no freshness gate: every query is live.

The report is a one-liner over that table:

```
SELECT os_name, state, state_reason, needs_action, action FROM windows_yellowkey;
```

Verdicts:

| Verdict | Meaning |
|---|---|
| `not_affected` | Windows 10 |
| `mitigated` | `BootExecMitigated` marker set (mitigate script ran and verified clean) |
| `mitigated_winre_off` | WinRE disabled (heavier control) |
| `bitlocker_off` | No BitLocker volume, or none protecting |
| `exposed` | Affected OS + BitLocker on + no mitigation marker |
| `unknown` | Unrecognised OS |

A host returns rows here only once the extension is loaded. Hosts pending the extension show up as failing the `windows-yellowkey-extension` policy, which installs it.

Mitigate
--------

`mitigate-windows-yellowkey.ps1` is a Fleet-flavored adaptation of [Microsoft's canonical script](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585). The Microsoft flow:

1. `reagentc /mountre /path <dir>` to mount the WinRE image.
2. `reg load` the offline `SYSTEM` hive.
3. Walk every `ControlSet*` child key and strip `autofstx` variants from `Control\Session Manager\BootExecute`.
4. `reg unload` and `reagentc /unmountre /commit`.
5. `reagentc /disable` + `/enable` to re-seal the BitLocker measurement chain.

Fleet adds:

- Mount path under `%SystemRoot%\Temp`, ACL-locked to Administrators.
- Mount + edit + unmount in one try/finally so the hive and mount are always released.
- Read-back verification per ControlSet. Refuses to write the success marker unless every ControlSet is clean.
- Writes `HKLM\SOFTWARE\Fleet\YellowKey\BootExecMitigated = 1` only when the edit completes without exception.
- Granular exit codes for Fleet reporting: `0` ok, `3` OS not affected, `4` mount/edit/unmount/re-seal failed.

No opt-in gate. Microsoft's autofstx strip is safe to apply on every affected host. One-way: there is no unmitigate. If a patch ships, apply it and clear the marker manually.

Deploy
------

Two pieces keep the detection extension installed across the fleet:

- The `windows-yellowkey-extension` policy queries osquery's `file` table for `windows_yellowkey-*.exe` under `C:\Program Files\Fleet\Extensions\`. Passes when the binary is present.
- `install-yellowkey-extension.ps1` is attached as the policy's `run_script`. It detects host architecture, downloads the matching binary from the latest GitHub release, verifies the PE32+ MZ header, and drops it at the target path. Idempotent.

Releases come from `.github/workflows/build-extensions.yml`. Push a tag matching `v*` or `extensions-v*` and the workflow auto-discovers every `extensions/<name>/`, runs `make windows`, and uploads the resulting `.exe` files as release assets:

```
git tag v1.0.0
git push --tags
```

That is the only manual step. Fleet's policy auto-installs the extension on hosts as they check in; Fleet caps `run_script` retries at 3 per failure, so a host that cannot install (no egress, locked-down endpoint, etc.) stays failing until an admin intervenes.

Drop-in
-------

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
    - path: ../lib/windows/scripts/verify-windows-yellowkey.ps1
```

Apply with:

```
fleetctl gitops -f fleets/workstations.yml
```

Workflow
--------

1. **Push the GitOps config.** Policy, report, and scripts land in Fleet.
2. **Cut a release.** `git tag v1.0.0 && git push --tags`. The workflow builds and publishes the binaries.
3. **Wait for hosts to install.** Policy runs the installer on failing hosts on the next check-in.
4. **Open the report.** Hosts with `state = 'exposed'` are the candidates.
5. **Run `mitigate-windows-yellowkey.ps1`** against those hosts via Fleet > Controls > Scripts. Target by label.
6. **Re-run the report.** Exposed hosts move to `mitigated`.

Operational notes
-----------------

- **No extension, no row.** A host reports in the `windows-yellowkey` report only once the extension is loaded. Until then it shows up as failing the `windows-yellowkey-extension` policy, which installs the extension. The two views together cover the whole fleet: the policy says who still needs the extension, the report says the state of everyone who has it.
- **Verify is the per-host inspector.** `verify-windows-yellowkey.ps1` reads `reagentc /info`, BitLocker key protectors via `Get-BitLockerVolume`, and the success marker. It needs no osquery, so it works as a standalone second opinion when a host disagrees with the report.
- **Recovery media changes after `reagentc /disable`.** The heavier escalation removes push-button reset, the in-WinRE BitLocker recovery flow, System Restore from boot, and Recovery Drive image restore. Re-enable with `reagentc /enable` before any of those operations is needed.
- **When the patch ships.** Apply it and clear `HKLM\SOFTWARE\Fleet\YellowKey\BootExecMitigated` to retire the marker. The mitigate script is one-way and does not auto-clear.
- **Don't trust TPM-only.** Move high-risk hosts to TPM + PIN where the threat model includes physical access. PIN blocks the public PoC and raises attacker cost on the withheld variant.

Wrap-up
-------

Three pieces, one threat. An osquery extension that watches every Windows host in real time. A Fleet policy that keeps the extension installed. A script that runs Microsoft's mitigation when a host shows up exposed. Pin the YAML, push the tag, watch the report drain.
