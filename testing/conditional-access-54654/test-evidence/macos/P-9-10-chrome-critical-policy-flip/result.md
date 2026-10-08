# macOS P-9 / P-10: critical policy flip, Chrome sign-in
- **Date:** 2026-10-08 (UTC), host `MPC-Adam` (macOS, Fleet host 12), renewed certificate `F7313E7E...`.
- **Steps:** create `/tmp/fleet-ca-test` (critical policy `CA test: flag file absent` fails), refetch the host, wait for Fleet's `failing_critical_policies_count` to reach 1, sign in with Chrome; then remove the file, refetch, wait for 0, sign in again.
- **Result: PASS.**
  - Failing: Fleet saw the change 61 s after the file was created. Chrome sign-in ended at `error=access_denied` with "Host is not in Fleet or is failing a critical policy" (`02-chrome-denied.png`, `02-chrome-denied.url.txt`).
  - Passing: Fleet saw the change 66 s after the file was removed. Chrome signed in straight to the callback with a code (`04-chrome-restored.png`; the code is masked).
- Evidence: `01-flip-to-failing.txt`, `03-flip-to-passing.txt` (timings), the four files above. Screenshots are single Chrome windows (window capture), with the sign-in code and the browser profile area masked. No certificate picker or keychain prompt appeared.
