# Brief: Staged Windows MDM migration script

Issue: 59195 (parent: none) · Customer: `customer-numa` · Fleet version to test: lab Fleet (confirm the customer's version) · Written: 2026-11-23

## Background
Fleet's automatic Windows migration (`windows_mdm_migration_enabled`) is one global switch. When it's on, every eligible Windows host on every fleet leaves its current MDM at its next fleetd check-in. The customer has a large Intune estate and won't move it all at once. Intune delivers their Wi-Fi and network certificates, so a bad switch takes users offline. They want to move a pilot group first, then a label or a fleet at a time.

After an on-site kickoff, the product team filed the issue for a best-practice script. A second customer asked for the same staged plan in October. A PR adds `docs/solutions/windows/scripts/windows-migrate-to-fleet-mdm.ps1` (head `d44c91c`). Full story with names: `private/CONTEXT.md`.

## The ask
Prove that a script run from Fleet on chosen hosts moves a Windows host from Intune to Fleet MDM without a reset and without losing the Entra join. Prove that it does so with automatic migration off. Confirm whether fleetd turns on Fleet MDM by itself after the unenroll (the issue's open question), and document how to stage the rollout.

### What the issue asked vs. what the PR does
| Issue task | PR |
|---|---|
| Script that does step 1 only (unenroll with `UnregisterDeviceWithManagement`), skips Windows Server, and reports clearly | Done, but it also does step 2: it calls `RegisterDeviceWithManagement` with the orbit node key. |
| Test on a host enrolled in another MDM, run from Fleet | No test notes in the PR. |
| Document staged rollout (label or fleet at a time) in a guide | Not done. No guide change. |
| Raise needed product fixes in the product channel | Not mentioned. |

## What needs testing
1. Does the script move an Intune-managed, Entra-joined host to Fleet MDM, run from Fleet, with automatic migration off? → T-1, T-2
2. With automatic migration off and manual mode off, does fleetd turn on Fleet MDM by itself after the unenroll? This decides whether the script needs its own enroll step. → T-3
3. Does the script still work when `enable_turn_on_windows_mdm_manually` is on (fleetd won't enroll)? → T-4
4. What happens to the old MDM's Wi-Fi and certificate profiles, and how long is the host without them? → T-5
5. Do the safety paths hold: Server, a preflight failure, a stale enrollment key, a rerun? → T-6 to T-9
6. Does staging work: only the targeted hosts move, the others stay on Intune? → T-10

## Lab needed
| Item | Have it? | Notes |
|---|---|---|
| Fleet | yes, lab Fleet with Windows MDM on | Automatic migration must stay off. T-4 needs manual mode on, which is global, so it changes the lab Fleet. |
| Fleet for the test | needs `fleets/win-migration-lab.yml` (PR you merge) | Two hosts, plus a label `Windows migration - wave 1` for T-10. |
| Hosts | 2 Windows 11 VMs (QEMU arm64) | 1 Windows Server VM for T-6, or a faked `InstallationType`. |
| Intune + Entra | **no** | Blocked in project `intune-entra-ids-44916`. Needs a tenant with Intune licenses and auto-enrollment. A second Fleet can't stand in: the script treats ProviderID `Fleet` as already migrated. |
| Old MDM payload | needs a Wi-Fi profile and a SCEP/PKCS cert in Intune | For T-5. |

## Plan
| ID | Test | Pass when | Runs by | Est. time |
|---|---|---|---|---|
| R-1 | Code check against fleetd and the server | Done in review: unenroll call, token shape, device API, MDM On rule match. Open items logged in NOTES. | agent now | done |
| T-1 | Happy path from Fleet: Entra joined + Intune host, run the script | Exit 0. Fleet shows `On (manual)`, name Fleet. Intune shows the device unmanaged. `dsregcmd /status` still `AzureAdJoined : YES`. No reboot or reset. | you (Intune) + overnight queue (VM) | 30 min |
| T-2 | Script output and timing | One `RESULT exit=` line. No node key or device token in Fleet's script output. Total run under 300 s. | agent now (reads T-1 output) | 5 min |
| T-3 | Unenroll only, fleetd enrolls | Run a step-1-only copy. Within 10 min, Fleet MDM turns on with no further action. Record the time. | overnight queue | 30 min |
| T-4 | Manual mode on | Script still ends with exit 0. Then set manual mode back off. | you (changes lab Fleet) | 30 min |
| T-5 | Old MDM payload | Record when the Intune Wi-Fi profile and cert disappear, and when Fleet's profiles arrive. Report the gap in seconds. | you + overnight queue | 45 min |
| T-6 | Windows Server | Exit 1, no change in `Enrollments`. | overnight queue | 20 min |
| T-7 | Preflight failures: URL unset, AutoEnrollMDM GPO set, CcmExec present, Fleet unreachable | Exits 1, 2, 2, 3. Registry unchanged, still on Intune. | overnight queue | 30 min |
| T-8 | Stale key: an extra inactive `Enrollments` key with UPN and a discovery URL before running | Expected today: exit 5 after unenroll, host unmanaged (review finding). Pass for the fix: exit before any change. | overnight queue | 20 min |
| T-9 | Rerun on a migrated host | Exit 0, "already enrolled", no unenroll call. | overnight queue | 10 min |
| T-10 | Staged rollout | Run on the wave 1 label only. Only labelled hosts move. Others stay on Intune with automatic migration off. | you | 20 min |

## Not covered
- ConfigMgr co-management re-enrolling into Intune. The lab has no ConfigMgr. The script blocks on `CcmExec` by default.
- Fleet script timeouts below 300 s.
- x64 hardware. Lab VMs are arm64.

## Questions for you
- Is there a Fleet M365 dev or demo tenant with Intune we can use, or do you create an Intune trial? I can't create accounts.
- What Fleet version does the customer run? Test on the lab version if they match.
- OK to flip `enable_turn_on_windows_mdm_manually` on the lab Fleet for T-4? It's global.
- Test JP's PR as is, or wait for fixes to the review findings (stale-key preflight, docs)?

## After approval
Agents run the "agent now" tests in parallel, the queue runs the VM steps, and you do the "you" steps from a checklist.
About 3 Claude sessions on Sonnet.
