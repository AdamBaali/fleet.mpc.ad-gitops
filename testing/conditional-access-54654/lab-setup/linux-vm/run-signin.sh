#!/bin/bash
# Sign in to PingFederate from this host with its device certificate, like a browser would.
{
  echo "== ping.lab resolves to: $(getent hosts ping.lab)"
  curl -s -L --max-redirs 12 -c /dev/null -b /dev/null --cert /opt/company/certificate.pem --key /opt/company/CustomerUserNetworkAccess.key \
    -o /dev/null -w 'final_http=%{http_code}\nfinal_url=%{url_effective}\nredirects=%{num_redirects}\n' \
    "https://ping.lab:9031/as/authorization.oauth2?client_id=labclient&response_type=code&redirect_uri=http%3A%2F%2Flocalhost%3A8765%2Fcallback&state=lab"
  echo "curl exit=$?"
} > /tmp/signin.out 2>&1
