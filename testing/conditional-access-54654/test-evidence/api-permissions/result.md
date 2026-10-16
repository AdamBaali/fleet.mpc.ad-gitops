# API-only users with only the endpoints the guides list (2026-10-16)

**Result: PASS.** Both guides' "Specific API endpoints" lists are complete and sufficient on Fleet 4.93.0 (Premium).

Two throwaway API-only Observer users were created with `api_endpoints` set to exactly the guide lists, tested, then deleted.

| User | Allowed (guide list) | Result | Anything else |
| --- | --- | --- | --- |
| PingFederate | `GET /hosts/identifier/:identifier`, `GET /hosts/:id/health` | both 200 | `GET /hosts` and `GET /reports/:id/report` 403 |
| Duo export | `GET /hosts`, `GET /reports/:id/report` | both 200 | `GET /hosts/:id/health` and `GET /hosts/identifier/:identifier` 403 |

The unmodified export script (only the URL and report ID filled in) ran to completion with the Duo token, with `REQUIRE_PASSING_CRITICAL_POLICIES` both `false` and `true`: it wrote macOS, Windows and Linux lists with no extra permission needed for `populate_policies`.

Notes for the guide: `PATCH /users/:id` rejects `api_endpoints` ("This endpoint does not accept API endpoint values"), so the list can only be set when the API-only user is created (or in the UI). The endpoint catalog is `GET /api/v1/fleet/rest_api`.
