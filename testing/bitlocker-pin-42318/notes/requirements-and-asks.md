# What was asked, and where it's answered

Consolidated 2026-10-16 from the GitHub issue (all comments) and the customer's support thread. Customer details are left out:
"the customer" needed the PIN for a certification audit.
Answers: [`drafts/issue-comment-42318.md`](../drafts/issue-comment-42318.md) (issue) and
[`drafts/customer-reply.md`](../drafts/customer-reply.md) (customer). Evidence IDs refer to [EVIDENCE.md](../EVIDENCE.md).

## The customer's requirements
| # | Requirement | Answer | Evidence |
|---|---|---|---|
| R1 | PIN **enforced** (an audit requirement), not optional | Fleet's setting and a PIN *Required* profile don't force it; IT can set it with a Fleet script and a policy reports hosts without one | C-1, C-2a, C-2b, C-3, PO-1 |
| R2 | 6-digit PIN, lock after 3 failed attempts | 6 digits: yes (min PIN length). 3 attempts: no setting; at startup the 6th wrong PIN forces recovery; TPM policy gives 32 / 2 h | PB-2, L-1 |
| R3 | No Fleet Desktop on clients | Covered: every customer-case test ran without Fleet Desktop | C-1..C-3, D-1 |
| R4 | Works for users who aren't admins | Setting the PIN: no (admin prompt). Changing an IT-set PIN: yes | C-1, D-1 |
| R5 | Not joined to AD/Entra or another MDM; Windows 11 Pro laptops and VMs, TPM 2.0 | Lab matched: not joined, Windows 11 Pro, TPM 2.0 | S-1b |
| R6 | Would configure BitLocker themselves with their own profile | Yes since Fleet 4.90 with `mdm.enable_custom_disk_encryption` (Fleet turns it on for cloud) | S-3 |
| R7 | Their devices showed "only USB" as a startup option | Windows classifies them as tablets ("Slate"); the slates setting, sent as a Fleet profile, fixes it | SL-1..SL-6 |
| R8 | A fix date for a path without Fleet Desktop, or a clear "not supported" | Clear statement + workaround; no date for a non-Fleet-Desktop path | Comment |

## Asks in the issue thread (fleetdm/fleet#42318)
| # | Who, when | Ask | Answer |
|---|---|---|---|
| 1 | Adam, 03-24 (issue body) | Update docs; script to clean up registry values so users can add a PIN | No cleanup needed or possible (CSP-owned values revert); Fleet's payload shows "Enter a PIN" on a desktop-class device. Docs fix still needed (PR #43915 is wrong) |
| 2 | Victor, 03-31 | Physical devices stop refetching with PIN on | Not reproduced on the VM; not verified on hardware |
| 3 | Victor, 04-17 | His *Required* test: user couldn't set a PIN | With the other methods *Disallowed*, an admin could; his setup likely left them at Allow (not tested) |
| 4 | Noah/Juan, 04-20–21 | "Requiring a PIN only works on unencrypted hosts" | Corrected: a PIN was added to an encrypted drive with PIN Required |
| 5 | Victor, 04-21 | What to recommend for audits: policy + script? | Workaround: profile C + Fleet script sets the PIN + PIN policy (all tested) |
| 6 | Marko, 04-27 | Script that removes registry values blocking the PIN, no pop-up | Premise disproved (B-2); policy half tested; script that sets the PIN tested |
| 7 | Magnus 08-05, Noah 08-10, Dale 10-13 | Status / findings / update | Answered by the comment |
| 8 | Luke, 08-31 | Is this a bug? | Not in Fleet's payload; gaps are non-admin PIN without Fleet Desktop, and the slates setting Fleet doesn't send |

## Customer questions (support thread)
| When | Question | Answer |
|---|---|---|
| 2025-12 | Will the PIN work for non-admin users? | Not without Fleet Desktop today; Fleet 4.93's My device form + fleetd 1.62 + Fleet Desktop does it |
| 2025-12 | Only USB offered at startup | R7 |
| 2026-01 | Can we upload our own BitLocker profile? | R6 |
| 2026-01 | 6 digits, lock after 3 attempts | R2 |
| 2026-03 | Fix date, or a clear "not supported" | R8 |
| 2026-04 | Any deadline? | No date for a non-Fleet-Desktop path |
| 2026-09 | PIN banner on fleets without PIN enabled | Fixed in Fleet 4.92 + fleetd 1.61 (#51998) |

## Not covered
Refetch stalls on physical devices; a standard user completing a PIN change (dialog and lockout tested only); TPM+PIN (rather
than a startup password) on the slate VM.
