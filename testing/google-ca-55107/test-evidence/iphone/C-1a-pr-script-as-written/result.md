# C-1a: the PR #55107 sync script as written, against the real iPhone

- **Date:** 2026-10-09
- **Objective:** Run the guide's script word for word (only the Fleet URL and customer ID filled in)
- **Expected:** `none -> MANAGED` and a client state written

## Steps and evidence
- `01` DRY_RUN: matches the iPhone to the Fleet host: `(<managed test user>/iphone): none -> MANAGED`. Matching works on real data.
- `02` LIVE: the first `clientStates.patch` returns **HTTP 400 "Request contains an invalid argument"**, curl exits 56, the run stops. Nothing written.
- `03` cause, all four combinations tried:

| Partner ID | `customer=` | HTTP |
|---|---|---|
| `<customer-ID>-fleet` (guide) | `customers/<customer-ID>` (guide) | 400 |
| `<customer-ID>-fleet` | `customers/my_customer` | 403 |
| `<id-without-C>-fleet` | `customers/<customer-ID>` | 400 |
| `<id-without-C>-fleet` | `customers/my_customer` | **200** |

- `04`: phone still blocked after the write (expected: the access level used the guide's `<customer-ID>-fleet` key).

## Result: FAIL

Two script bugs: the partner ID must drop the leading "C" (Google's reference says so), and the state calls must use `customers/my_customer` (Google's own sample sends no customer).
