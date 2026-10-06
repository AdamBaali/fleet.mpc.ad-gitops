# Conditional access guides: lab testing (fleetdm/fleet#54654)

Test lab for the PingFederate and Duo guides in fleetdm/fleet PR #54346. Everything here is from a throwaway test environment.

- `GUIDE-FINDINGS.md`: what to change in each guide.
- `RESULTS.md`: every test with date, steps, result and evidence, in the order they were run.
- `TEST_PLAN.md`: the test cases (P-n PingFederate, D-n Duo, L-n Linux).
- `ping/`: PingFederate in Docker plus the Admin API setup scripts (`setup/01` to `09`) and the sign-in test scripts.
- `stepca/`, `cloudflared/`: the lab CA (SCEP, client and server certificates) and the tunnel config.
- `linux-vm/`: builds the Ubuntu test VM in UTM from the official cloud image with cloud-init, and helpers to run commands in it.
- `duo/`: start script for Duo's Universal Prompt demo.
- `tests/`: mock Fleet and the export script tests.
- `patches/`: proposed fix for `import-certificate-to-browsers.sh`.

No credentials are stored here. Scripts read them from a local `.env` that is not in this repo.
