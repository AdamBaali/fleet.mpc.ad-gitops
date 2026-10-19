#!/bin/sh
#
# Installs and loads the software_itam osquery extension on this Mac
# (fleetdm/fleet#38864).
#
# Fleet run_script remediation for the software-itam-extension policy. The
# policy fails when the software_itam table is not registered.
#
# Why a pinned commit and SHA-256: the binary runs as root on every host in
# the fleet. Pinning means a change upstream can't reach hosts until someone
# updates these two values here, through a reviewed GitOps change.
#
# Why /var/osquery/extensions.load: it is osquery's compiled-in default
# autoload file on macOS, used when orbit passes no --extensions_autoload.
# Orbit's own /opt/orbit/extensions.load is managed by Fleet's
# agent_options.extensions and is emptied when that is unset, so it would
# drop this entry.
#
# Idempotent. Exit codes:
#   0  installed (or already current); orbit restarted when anything changed
#   3  orbit launch daemon not found
#   4  filesystem operation failed
#   6  download failed or checksum mismatch
#   8  unsupported architecture

set -eu

EXT_NAME='software_itam'
EXT_COMMIT='1c520ee80a44dddfe798169f7fbe114c4ccf5140'
SHA256_X86_64='e0d68f7324e81c6e4ad6877787a89c14dc54c6f39baad2ed85fc7167346bd430'
SHA256_ARM64='7f9c9889ec2ddebd6d5f036a9e8d0f63904815fdc06c21026fd495892c5c809b'
BASE_URL="https://raw.githubusercontent.com/AdamBaali/fleet-extensions/${EXT_COMMIT}/software_itam"

OSQUERY_HOME='/var/osquery'
EXT_DIR="${OSQUERY_HOME}/extensions"
EXT_PATH="${EXT_DIR}/${EXT_NAME}.ext"
LOADER="${OSQUERY_HOME}/extensions.load"
ORBIT_LABEL='system/com.fleetdm.orbit'

echo "=== ${EXT_NAME} osquery extension installer ==="

case "$(uname -m)" in
  x86_64) asset="${EXT_NAME}-x86_64.ext"; want="${SHA256_X86_64}" ;;
  arm64) asset="${EXT_NAME}-arm64.ext"; want="${SHA256_ARM64}" ;;
  *) echo "FAIL: unsupported architecture: $(uname -m)"; exit 8 ;;
esac

if ! launchctl print "${ORBIT_LABEL}" >/dev/null 2>&1; then
  echo "FAIL: ${ORBIT_LABEL} not found. Is fleetd installed?"
  exit 3
fi

changed=0
have=''
[ -f "${EXT_PATH}" ] && have="$(shasum -a 256 "${EXT_PATH}" | awk '{print $1}')"

if [ "${have}" = "${want}" ]; then
  echo "Binary already current (${want})"
else
  tmp="$(mktemp)"
  trap 'rm -f "${tmp}"' EXIT
  echo "Downloading ${BASE_URL}/${asset}"
  if ! curl -fsSL --retry 3 --connect-timeout 15 -o "${tmp}" "${BASE_URL}/${asset}"; then
    echo "FAIL: download failed"
    exit 6
  fi
  got="$(shasum -a 256 "${tmp}" | awk '{print $1}')"
  if [ "${got}" != "${want}" ]; then
    echo "FAIL: checksum mismatch: got ${got}, want ${want}"
    exit 6
  fi
  # osquery refuses an extension that is group- or world-writable, or in a
  # directory that is, so both are root-owned and 0755.
  if ! install -d -o root -g wheel -m 0755 "${OSQUERY_HOME}" "${EXT_DIR}" \
    || ! install -o root -g wheel -m 0755 "${tmp}" "${EXT_PATH}"; then
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
  # orbit sends the result to Fleet. The detached restart waits 30 seconds,
  # then kickstart -k restarts orbit and its osqueryd.
  echo "Restarting orbit in 30 seconds so osqueryd loads the extension"
  (sleep 30; launchctl kickstart -k "${ORBIT_LABEL}") >/dev/null 2>&1 &
fi

echo "Done. Verify: SELECT 1 FROM osquery_registry WHERE registry = 'table' AND name = '${EXT_NAME}' AND active = 1;"
exit 0
