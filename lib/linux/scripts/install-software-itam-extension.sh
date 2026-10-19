#!/bin/sh
#
# Installs and loads the software_itam osquery extension on this Linux host
# (fleetdm/fleet#38864).
#
# Fleet run_script remediation for the software-itam-extension policy. The
# policy fails when the software_itam table is not registered.
#
# Why a pinned commit and SHA-256: the binary runs as root on every host in
# the fleet. Pinning means a change upstream can't reach hosts until someone
# updates these values here, through a reviewed GitOps change.
#
# Why /etc/osquery/extensions.load: it is osquery's compiled-in default
# autoload file on Linux, used when orbit passes no --extensions_autoload.
# Orbit's own /opt/orbit/extensions.load is managed by Fleet's
# agent_options.extensions and is emptied when that is unset. /etc and /var
# stay writable on rpm-ostree hosts, where /usr and /opt are read-only.
#
# Idempotent. Exit codes:
#   0  installed (or already current); orbit restart scheduled when anything changed
#   3  orbit service not found
#   4  filesystem operation failed
#   6  download failed or checksum mismatch
#   8  unsupported architecture

set -eu

EXT_NAME='software_itam'
EXT_COMMIT='1c520ee80a44dddfe798169f7fbe114c4ccf5140'
SHA256_AMD64='436553a59b3696750b3c1c388d80450200965b67f3597607a0154dc13d23bbfd'
SHA256_ARM64='09cd1a3b5e20c447c6c16be3ef8a18dd6e13a3bbb50656baedfcab790dc7885d'
BASE_URL="https://raw.githubusercontent.com/AdamBaali/fleet-extensions/${EXT_COMMIT}/software_itam"

EXT_DIR='/var/osquery/extensions'
EXT_PATH="${EXT_DIR}/${EXT_NAME}.ext"
LOADER='/etc/osquery/extensions.load'

echo "=== ${EXT_NAME} osquery extension installer ==="

case "$(uname -m)" in
  x86_64 | amd64) asset="${EXT_NAME}-amd64.ext"; want="${SHA256_AMD64}" ;;
  aarch64 | arm64) asset="${EXT_NAME}-linux-arm64.ext"; want="${SHA256_ARM64}" ;;
  *) echo "FAIL: unsupported architecture: $(uname -m)"; exit 8 ;;
esac

if systemctl cat orbit.service >/dev/null 2>&1; then
  service='orbit.service'
elif systemctl cat fleetd.service >/dev/null 2>&1; then
  service='fleetd.service'
else
  echo "FAIL: neither orbit.service nor fleetd.service is present"
  exit 3
fi

changed=0
have=''
[ -f "${EXT_PATH}" ] && have="$(sha256sum "${EXT_PATH}" | awk '{print $1}')"

if [ "${have}" = "${want}" ]; then
  echo "Binary already current (${want})"
else
  tmp="$(mktemp)"
  trap 'rm -f "${tmp}"' EXIT
  echo "Downloading ${BASE_URL}/${asset}"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 --connect-timeout 15 -o "${tmp}" "${BASE_URL}/${asset}" || { echo "FAIL: download failed"; exit 6; }
  elif command -v wget >/dev/null 2>&1; then
    wget -q -t 3 -T 15 -O "${tmp}" "${BASE_URL}/${asset}" || { echo "FAIL: download failed"; exit 6; }
  else
    echo "FAIL: neither curl nor wget is available"
    exit 6
  fi
  got="$(sha256sum "${tmp}" | awk '{print $1}')"
  if [ "${got}" != "${want}" ]; then
    echo "FAIL: checksum mismatch: got ${got}, want ${want}"
    exit 6
  fi
  # osquery refuses an extension that is group- or world-writable, or in a
  # directory that is, so both are root-owned and 0755.
  if ! install -d -o root -g root -m 0755 /var/osquery "${EXT_DIR}" /etc/osquery \
    || ! install -o root -g root -m 0755 "${tmp}" "${EXT_PATH}"; then
    echo "FAIL: could not install ${EXT_PATH}"
    exit 4
  fi
  echo "Installed ${EXT_PATH} (${want})"
  changed=1
fi

if [ -f "${LOADER}" ] && grep -qxF "${EXT_PATH}" "${LOADER}"; then
  echo "${LOADER} already lists the extension"
else
  if ! printf '%s\n' "${EXT_PATH}" >>"${LOADER}" || ! chmod 0644 "${LOADER}"; then
    echo "FAIL: could not write ${LOADER}"
    exit 4
  fi
  echo "Added ${EXT_PATH} to ${LOADER}"
  changed=1
fi

if [ "${changed}" -eq 1 ]; then
  # orbit runs this script, so restarting it now would kill the script before
  # orbit sends the result to Fleet. systemd-run starts the restart outside
  # orbit's cgroup, 30 seconds from now.
  if systemd-run --on-active=30 --unit="${EXT_NAME}-orbit-restart" systemctl restart "${service}" >/dev/null 2>&1; then
    echo "Scheduled ${service} restart in 30 seconds"
  else
    echo "WARN: could not schedule a restart; the extension loads on the next ${service} restart"
  fi
fi

echo "Done. Verify: SELECT 1 FROM osquery_registry WHERE registry = 'table' AND name = '${EXT_NAME}' AND active = 1;"
exit 0
