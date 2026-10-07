# P-5: Fleet REST data store connection

- **Started:** 2026-10-07T18:07:08Z
- **Objective:** PingFederate's REST data store can call Fleet with the Observer API token.
- **Expected:** Test Connection succeeds; Fleet returns the three values the guide maps (host UUID, host ID, failing critical policy count).

## Steps and evidence
- `01-datastore-config.txt`: `curl -sk -u Administrator:$PING_ADMIN_PASSWORD -H 'X-XSRF-Header: PingFederate' https://localhost:9999/pf-admi`
- `02-test-connection.txt`: `curl -sk -X POST -u Administrator:$PING_ADMIN_PASSWORD -H 'X-XSRF-Header: PingFederate' https://localhost:9999`
- `03-fleet-lookup-1.txt`: `curl -s -H "Authorization: Bearer $FLEET_TOKEN_PING" "$FLEET_URL/api/v1/fleet/hosts/identifier/86d7dc8e-3373-4`
- `04-fleet-lookup-2.txt`: `HID=$(curl -s -H "Authorization: Bearer $FLEET_TOKEN_PING" "$FLEET_URL/api/v1/fleet/hosts/identifier/86d7dc8e-`
- `05-observer-role.txt`: `curl -s -H "Authorization: Bearer $FLEET_TOKEN_PING" $FLEET_URL/api/v1/fleet/me | jq '{name:.user.name,global_`

## Result: **PASS**

PingFederate Test Connection returned HTTP 200; with the Observer-only token Fleet returned the host UUID, host ID and failing_critical_policies_count.

_Finished 2026-10-07T18:07:26Z_
