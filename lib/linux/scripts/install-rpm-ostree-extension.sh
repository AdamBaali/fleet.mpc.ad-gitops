#!/usr/bin/env bash
#
# Installs and loads the rpm_ostree osquery extension on this host.
#
# Fleet run_script remediation for the rpm-ostree-extension policy. The
# policy fails when the rpm_ostree_deployments table is not registered;
# this script downloads the architecture-matching binary, places it on the
# only writable surface an atomic host has (/var), registers it with
# osquery, and restarts orbit. osqueryd autoloads the extension on the next
# start.
#
# Why /var/lib/fleetd: on rpm-ostree hosts (Silverblue, Bluefin, CoreOS)
# /usr is read-only and /opt is part of the immutable image. /var is the
# only persistent writable mount, and orbit already keeps its root there.
# The extension binary is statically linked, so it carries no dependency on
# the host's (frozen) /usr.
#
# Idempotent: re-running re-asserts the binary, the loader flag, and the
# restart, so a host that drifted self-heals on the next policy run. Fleet
# caps run_script retries at 3 per failure.
#
# Exit codes:
#   0  installed (or already current); orbit restarted
#   3  orbit/fleetd service not found (host not enrolled through orbit)
#   4  filesystem operation failed
#   6  download failed or asset is not a valid ELF executable
#   8  unsupported architecture

set -euo pipefail

REPO_RAW='https://raw.githubusercontent.com/AdamBaali/fleet-extensions/main/rpm_ostree'
FLEETD_DIR='/var/lib/fleetd'
EXT_DIR="${FLEETD_DIR}/extensions"
EXT_PATH="${EXT_DIR}/rpm_ostree.ext"
FLAGS_FILE="${FLEETD_DIR}/osquery.flags"
EXT_FLAG="--extension=${EXT_PATH}"

echo "=== rpm_ostree osquery extension installer ==="

# 1. Pick the binary that matches this host's architecture.
arch="$(uname -m)"
case "$arch" in
  x86_64 | amd64) asset='rpm_ostree-amd64.ext' ;;
  aarch64 | arm64) asset='rpm_ostree-arm64.ext' ;;
  *)
    echo "FAIL: unsupported architecture: ${arch}"
    exit 8
    ;;
esac
echo "Host arch ${arch} -> ${asset}"

# 2. Download to a temp file, then validate before touching the live path.
tmp="$(mktemp)"
# shellcheck disable=SC2064
trap "rm -f '${tmp}'" EXIT

url="${REPO_RAW}/${asset}"
echo "Downloading ${url}"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL --retry 3 --connect-timeout 15 -o "${tmp}" "${url}" || {
    echo "FAIL: download failed (curl): ${url}"
    exit 6
  }
elif command -v wget >/dev/null 2>&1; then
  wget -q -t 3 -T 15 -O "${tmp}" "${url}" || {
    echo "FAIL: download failed (wget): ${url}"
    exit 6
  }
else
  echo "FAIL: neither curl nor wget is available"
  exit 6
fi

# Sanity-check the magic bytes (0x7f 'E' 'L' 'F'). Catches truncated
# downloads and HTML error pages without pinning a hash in source.
magic="$(head -c 4 "${tmp}" | od -An -tx1 | tr -d ' \n')"
if [ "${magic}" != "7f454c46" ]; then
  echo "FAIL: downloaded asset is not an ELF executable (magic=${magic})"
  exit 6
fi
echo "Validated ELF binary ($(wc -c <"${tmp}") bytes)"

# 3. Place the binary. osquery refuses to load an extension that is
#    group- or world-writable, so install it 0700 root:root.
if ! mkdir -p "${EXT_DIR}"; then
  echo "FAIL: could not create ${EXT_DIR}"
  exit 4
fi
if ! install -o root -g root -m 0700 "${tmp}" "${EXT_PATH}"; then
  echo "FAIL: could not install ${EXT_PATH}"
  exit 4
fi
echo "Installed ${EXT_PATH}"

# 4. Register the extension with osquery, idempotently.
if ! touch "${FLAGS_FILE}"; then
  echo "FAIL: could not write ${FLAGS_FILE}"
  exit 4
fi
if grep -qF -- "${EXT_FLAG}" "${FLAGS_FILE}"; then
  echo "Loader flag already present in ${FLAGS_FILE}"
else
  echo "${EXT_FLAG}" >>"${FLAGS_FILE}"
  echo "Added loader flag to ${FLAGS_FILE}"
fi

# 5. Restart the agent so osqueryd reloads with the extension. orbit is the
#    service name on fleetd; fall back to fleetd.service on older packages.
if systemctl list-unit-files orbit.service >/dev/null 2>&1 \
  && systemctl cat orbit.service >/dev/null 2>&1; then
  service='orbit.service'
elif systemctl cat fleetd.service >/dev/null 2>&1; then
  service='fleetd.service'
else
  echo "FAIL: neither orbit.service nor fleetd.service is present"
  exit 3
fi

if ! systemctl restart "${service}"; then
  echo "FAIL: could not restart ${service}"
  exit 4
fi

echo "Restarted ${service}"
echo "Done. The rpm_ostree_deployments table registers on the next osquery start."
exit 0
