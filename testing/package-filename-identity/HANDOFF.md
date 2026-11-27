# Handoff: package-filename-identity

## State
The lab fleet, the base package and the test scripts are on the branch `package-filename-identity`. Nothing has
run against the lab yet. The code read is in NOTES.md.

## Next steps
1. Merge the branch. The GitOps apply creates the Package Identity Lab fleet with the base script package.
2. Copy a `fleet.env` with `FLEET_URL` and `FLEET_API_TOKEN` into `private/`.
3. Run `bash scripts/run-tests.sh` from this folder. Read each output, set verdicts, fill RESULTS.md.
4. Take a UI screenshot of T-3 (Software, the title, "Add package") for the feature request.
5. Confirm the customer's package type, then file `drafts/feature-request.md`.

## Running services (keep them on)
None.

## Teardown
- T-4 and T-6 add packages and a `probe-tool.tar.gz` title to the lab fleet. The next GitOps apply removes them,
  because they aren't in `fleets/package-identity-lab.yml`.
- When the request is closed, delete `fleets/package-identity-lab.yml` and the base package, then apply.

## Rules learned
- Use `--form-string` for every form value but the file, so a value that starts with `@` is never read as a path.
