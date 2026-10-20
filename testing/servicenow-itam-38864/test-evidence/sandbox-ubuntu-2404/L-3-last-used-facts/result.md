# L-3: Last used: facts

- **Started:** 2026-10-20T09:01:25Z
- **Objective:** Record what Fleet's built-in last_opened_at depends on
- **Expected:** Mount options and osquery version saved. The value itself needs a Fleet server

## Steps and evidence
- `01-facts.txt`: `/repo/testing/servicenow-itam-38864/scripts/gt-linux.sh facts; /osq/opt/osquery/bin/osqueryd --version`

## Result: NOT-RUN

Built-in last_opened_at is computed by the Fleet server. Facts saved for the real host run

_Finished 2026-10-20T09:01:25Z_
