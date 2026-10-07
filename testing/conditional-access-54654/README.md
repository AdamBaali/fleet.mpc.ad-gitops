# Conditional access guides: lab testing (fleetdm/fleet#54654)

Test lab for the PingFederate and Duo guides in fleetdm/fleet PR #54346. Everything here is from a throwaway test environment.

- `HANDOFF.md`: **start here**. The project, where everything is, status, open items, working rules, and how to resume.
- `test-evidence/linux/REPORT.md`: **the Linux test report** (22 pass, 2 partial, 0 fail) with a folder of evidence per test: raw output, VM screenshots, sanitized config, Duo admin records.
- `NOTES.md`: what is tested vs not tested, and what to run next.
- `fleet-54654-fixes.diff`: the proposed guide and script changes (not yet a PR).
- `STATUS.md`: test matrix across macOS, Linux and Windows, what is running, next steps.
- `VALIDATION.md`: checks to run in the PingFederate UI before any finding is posted.
- `GUIDE-FINDINGS.md`: what to change in each guide.
- `RESULTS.md`: every test with date, steps, result and evidence, in the order they were run.
- `TEST_PLAN.md`: the test cases (P-n PingFederate, D-n Duo, L-n Linux).
- `ping/`: PingFederate in Docker plus the Admin API setup scripts (`setup/01` to `09`) and the sign-in test scripts.
- `stepca/`, `cloudflared/`: the lab CA (SCEP, client and server certificates) and the tunnel config.
- `linux-vm/`: builds the Ubuntu test VM in UTM from the official cloud image with cloud-init, and helpers to run commands in it.
- `duo/`: Duo demo start script, the keyless sync script (`device_cache_sync.py`), the export script and the sync loop. The Actions workflow is `.github/workflows/duo-sync.yml` in the repo root.
- `test-evidence/renewal/`: the log of the macOS certificate renewal watcher.
- `tests/`: mock Fleet and the export script tests.
- `patches/`: proposed fix for `import-certificate-to-browsers.sh`.

No credentials are stored here. Scripts read them from a local `.env` that is not in this repo.
