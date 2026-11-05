# S-1: fleets and profiles applied

- **Started:** 2026-11-05T09:04:34Z
- **Objective:** GitOps created the four fleets with the right profiles
- **Expected:** three fleets with pin-block-0, staging with none, the label fleet scoped to android-pin-ready

## Steps and evidence
- `01-version.txt`: `tools/setup-check.sh version`
- `02-fleets.txt`: `tools/setup-check.sh fleets`
- `03-profiles.txt`: `tools/setup-check.sh profiles`
- `04-labels.txt`: `tools/setup-check.sh labels`

- Applied by the push to main after the PR merge (GitHub Actions run 41998612551, success).

## Result: PASS

Fleet 4.94.0. Fleets 11-14 exist; three have pin-block-0, staging has none, the label fleet scopes it to android-pin-ready.

_Finished 2026-11-05T09:04:36Z_
