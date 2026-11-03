# Handoff: Mac readiness reports

Updated: 2026-11-03

## Where we are
- The five reports are generated and referenced from `default.yml`. They are on a branch, not merged.
- Done without a Mac: T-1 and T-2. The Fleet GitOps validator shows no new FAIL, and the SQLite logic check
  passes on a compliant and a non-compliant fixture (29 checks each).
- Not done: everything that needs a Mac (T-3 to T-11).
- The generator and the source mapping live in `private/`, which git ignores. Keep a copy outside this
  container; it is lost when the session ends.

## What's running
Nothing. The reports start on every lab Mac once the branch merges to `main`.

## Next steps
1. Open a pull request and let the CI dry run check the reports against the lab Fleet.
2. After merging, run T-3 on the lab Mac, then T-4.
3. Run T-7 early. If `courier.push.apple.com` isn't issued by Apple Inc., the interception check is wrong.
4. Run T-9 before adding more Macs. A firewall that drops packets is the case most likely to cause trouble.

## Teardown
- Remove the `path:` line from `default.yml` and delete the reports file. The reports and their stored results go with them.
- Remove any `pf` rules and the mitmproxy CA from the lab Mac after T-6 to T-9.
