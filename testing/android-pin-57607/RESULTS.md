# Results: require a PIN when company-owned Android hosts enroll (fleetdm/fleet#57607)

Plan: [TEST-PLAN.md](TEST-PLAN.md). Evidence per run: `test-evidence/<group>/<ID>-<slug>/` (build `EVIDENCE.md` with
`testing/_framework/bin/build-evidence-index.py`). Times are UTC. "T+" is minutes and seconds after the QR scan (T0).

Fleet version: _record in S-1_ · Enrollment: QR (zero-touch in Z) · Code references: `fleet-v4.94.0`

## Summary

| Option | Runs | Passed | Result | One line |
|---|---|---|---|---|
| 2: profile at enrollment (`android-pin-test-block0`) | | | | |
| 3: fleet move (`android-pin-staging` -> `android-pin-enforced`) | | | | |
| 3: label (`android-pin-label` + `android-pin-ready`) | | | | |
| 1: `blockAfterDays: 1` (optional) | | | | |
| Variant: `BLOCK_SCOPE_DEVICE` (optional) | | | | |
| Zero-touch confirmation | | | | |

## Setup

| ID | Date | Result | Notes |
|---|---|---|---|
| S-1 | | | Fleet version: |
| S-2 | | | Labels exception: on / off |
| S-3 | | | |
| S-4 | | | |
| S-5 | | | |

## Runs: device and setup wizard

| ID | Date | Device model | Android version | Security patch | New or re-enrolled host | Pace | T0 (UTC) | Host in Fleet (T+) | Profile Pending (T+) | Wizard screen when policy arrived | PIN prompt in setup (screen) | "Blocked by your work policy" (screen) | Way past the block | Home screen (T+) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| O2-1 | | | | | | Normal | | | | | | | | |
| O2-2 | | | | | | Normal | | | | | | | | |
| O2-3 | | | | | | Normal | | | | | | | | |
| O2-4 | | | | | | Slow | | | | | | | | |
| O2-5 | | | | | | Fast | | | | | | | | |
| O3F-1 | | | | | | Normal | | | | | | | | |
| O3F-2 | | | | | | Normal | | | | | | | | |
| O3F-3 | | | | | | Normal | | | | | | | | |
| O3F-4 | | | | | | Move on terms screen | | | | | | | | |
| O3F-5 | | | | | | Normal, staging QR after enforced | | | | | | | | |
| O3L-1 | | | | | | Normal | | | | | | | | |
| O3L-2 | | | | | | Normal | | | | | | | | |
| O3L-3 | | | | | | Normal, label kept | | | | | | | | |
| B1-1 | | | | | | Normal | | | | | | | | |
| V-1 | | | | | | Normal | | | | | | | | |
| Z-1 | | | | | | Normal | | | | | | | | |

## Runs: enforcement after setup

| ID | Fleet at enrollment | Move or label applied (T+) | Apps blocked (T+) | Apps blocked (which) | PIN prompt or notice after setup (T+) | PIN set (T+) | Profile status after PIN (T+) | Minutes usable without a PIN | Result | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| O2-1 | `android-pin-test-block0` | n/a | | | | | | | | |
| O2-2 | `android-pin-test-block0` | n/a | | | | | | | | |
| O2-3 | `android-pin-test-block0` | n/a | | | | | | | | |
| O2-4 | `android-pin-test-block0` | n/a | | | | | | | | |
| O2-5 | `android-pin-test-block0` | n/a | | | | | | | | |
| O3F-1 | `android-pin-staging` | | | | | | | | | |
| O3F-2 | `android-pin-staging` | | | | | | | | | |
| O3F-3 | `android-pin-staging` | | | | | | | | | |
| O3F-4 | `android-pin-staging` | | | | | | | | | |
| O3F-5 | `android-pin-staging` | n/a | | | | | | | | |
| O3L-1 | `android-pin-label` | | | | | | | | | |
| O3L-2 | `android-pin-label` | | | | | | | | | |
| O3L-3 | `android-pin-label` | label kept | | | | | | | | |
| B1-1 | `android-pin-test-block0` (block 1) | n/a | | | | | | | | |
| V-1 | `android-pin-test-block0` (device scope) | n/a | | | | | | | | |
| Z-1 | zero-touch: | | | | | | | | | |

Add a row to both tables for each extra run (O2-6, V-2, Z-2, and so on).

## Findings

_One section per finding, in the framework's format: steps, expected, actual, evidence, what Fleet or the guide should change._
