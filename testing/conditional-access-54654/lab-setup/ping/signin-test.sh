#!/usr/bin/env bash
# Drive a PingFederate sign-in with a client certificate, like a browser would.
# Usage: ping/signin-test.sh <cert.pem> <key.pem>   (no cert args = no client certificate)
LAB="$(cd "$(dirname "$0")/.." && pwd)"
ARGS=(--cacert "$LAB/ping/certs/step-ca-root.crt" --resolve ping.lab:9031:127.0.0.1 --resolve ping.lab:9032:127.0.0.1 -s -L --max-redirs 12 -c /dev/null -b /dev/null)
[ $# -ge 2 ] && ARGS+=(--cert "$1" --key "$2")
curl "${ARGS[@]}" -o /tmp/signin-body.html -w 'final_http=%{http_code}\nfinal_url=%{url_effective}\nredirects=%{num_redirects}\n' \
  "https://ping.lab:9031/as/authorization.oauth2?client_id=labclient&response_type=code&redirect_uri=http%3A%2F%2Flocalhost%3A8765%2Fcallback&state=lab"
