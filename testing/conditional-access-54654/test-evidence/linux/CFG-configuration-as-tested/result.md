# CFG: Configuration as tested

- **Started:** 2026-10-07T18:55:25Z
- **Objective:** Sanitized copies of the configuration the results depend on, so the lab can be rebuilt or shown to someone else.
- **Expected:** Everything the guides tell a customer to configure, in its working form.

## Steps and evidence
- `01-pf-x509-adapter.txt`: `curl -sk -u Administrator:$PING_ADMIN_PASSWORD -H 'X-XSRF-Header: PingFederate' https://localhost:9999/pf-admi`
- `02-pf-trusted-cas.txt`: `curl -sk -u Administrator:$PING_ADMIN_PASSWORD -H 'X-XSRF-Header: PingFederate' https://localhost:9999/pf-admi`
- `03-pf-policy-contract.txt`: `curl -sk -u Administrator:$PING_ADMIN_PASSWORD -H 'X-XSRF-Header: PingFederate' https://localhost:9999/pf-admi`
- `04-pf-authentication-policy.txt`: `curl -sk -u Administrator:$PING_ADMIN_PASSWORD -H 'X-XSRF-Header: PingFederate' https://localhost:9999/pf-admi`
- `05-pf-oauth-test-client.txt`: `curl -sk -u Administrator:$PING_ADMIN_PASSWORD -H 'X-XSRF-Header: PingFederate' https://localhost:9999/pf-admi`
- `06-pf-server-and-ports.txt`: `curl -sk -u Administrator:$PING_ADMIN_PASSWORD -H 'X-XSRF-Header: PingFederate' https://localhost:9999/pf-admi`
- `07-fleet-gitops-policies.txt`: `cat <gitops-repo>/lib/all/policies/ca-test.policies.yml ~/Documen`
- `08-fleet-gitops-fleet.txt`: `cat <gitops-repo>/fleets/ping-duo-lab.yml; echo; echo '--- certificate auth`
- `09-fleet-macos-scep-profile.txt`: `cat <gitops-repo>/lib/macos/configuration-profiles/lab-ca-scep-user.mobilec`
- `10-fleet-windows-scep-profile.txt`: `cat <gitops-repo>/lib/windows/configuration-profiles/lab-ca-scep-user.xml |`
- `11-fleet-chrome-autoselect-profile.txt`: `cat <gitops-repo>/lib/macos/configuration-profiles/lab-chrome-autoselect.mo`
- `12-duo-integrations-summary.txt`: `echo 'Three Generic Trusted Endpoints integrations in Duo (Generic with Duo Desktop): macOS (active, group fle`
