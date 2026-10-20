#!/usr/bin/env bash
# Runs run-sandbox-linux.sh in fresh Ubuntu and Fedora containers (fleetdm/fleet#38864).
#
# Usage: OSQ_DIR=/path/to/osquery-tarball-root ./run-sandbox-docker.sh [image ...]
#   OSQ_DIR  folder holding opt/osquery/bin/osqueryd from the osquery Linux tarball
#   image    default: ubuntu:24.04 fedora:41
#   CA_BUNDLE  optional CA file for a TLS-inspecting proxy, passed into the containers
#
# Why containers: each run needs a host with no earlier install of the test package in its package
# history, or the DEB first-install check reads an older run. A fresh container gives that every time.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
: "${OSQ_DIR:?set OSQ_DIR}"
[ $# -gt 0 ] || set -- ubuntu:24.04 fedora:41

for image in "$@"; do
  label="$(echo "$image" | tr -d '.' | tr ':' '-')"
  case "$image" in
    ubuntu*|debian*) prep='apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 curl ca-certificates time util-linux >/dev/null' ;;
    fedora*) prep='dnf install -y -q python3 curl time util-linux findutils >/dev/null' ;;
    *) echo "unsupported image $image" >&2; exit 1 ;;
  esac
  echo "=== $image ($label) ==="
  # When this runs behind a TLS-inspecting proxy, pass it and its CA into the container,
  # or HTTPS package downloads fail certificate checks.
  net=()
  for v in HTTPS_PROXY HTTP_PROXY NO_PROXY https_proxy http_proxy no_proxy; do [ -n "${!v:-}" ] && net+=(-e "$v"); done
  if [ -n "${CA_BUNDLE:-}" ] && [ -f "$CA_BUNDLE" ]; then
    net+=(-v "$CA_BUNDLE:/ca-bundle.crt:ro" -e CURL_CA_BUNDLE=/ca-bundle.crt -e SSL_CERT_FILE=/ca-bundle.crt)
  fi
  # Host networking, so a proxy on the host loopback is reachable from the container.
  docker run --rm --network host --hostname "$label" "${net[@]}" \
    -v "$REPO:/repo" -v "$OSQ_DIR:/osq:ro" \
    "$image" bash -c "$prep && OSQ=/osq/opt/osquery/bin/osqueryd GT_HOST=$label /repo/testing/servicenow-itam-38864/scripts/run-sandbox-linux.sh"
done
