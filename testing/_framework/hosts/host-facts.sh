#!/usr/bin/env bash
# Facts about a Linux or macOS test host, for the first evidence item of a test (the "S-0 facts" test).
# Run it on the host, or send it through a Fleet script, ssh, or the VM guest agent. Read-only, no root needed.
# It prints no IP addresses, user names, or serial numbers: the repo is public.
# Usage: host-facts.sh
set -uo pipefail
echo "utc_now        $(date -u +%FT%TZ)"
echo "kernel         $(uname -sr) $(uname -m)"
case "$(uname -s)" in
  Darwin)
    echo "os             macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
    echo "model          $(sysctl -n hw.model 2>/dev/null)"
    echo "power          $(pmset -g batt 2>/dev/null | head -1)"
    orbit=/opt/orbit/bin/orbit/macos/stable/orbit; osq=/opt/orbit/bin/osqueryd/macos-app/stable/osquery.app/Contents/MacOS/osqueryd ;;
  Linux)
    . /etc/os-release 2>/dev/null; echo "os             ${PRETTY_NAME:-unknown}"
    echo "virt           $(systemd-detect-virt 2>/dev/null || echo unknown)"
    echo "memory_mb      $(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)"
    echo "cpus           $(nproc)"
    echo "disk_free_gb   $(df -BG --output=avail / | tail -1 | tr -dc 0-9)"
    echo "package_mgr    $(for p in apt dnf rpm-ostree pacman zypper; do command -v $p >/dev/null && printf '%s ' $p; done)"
    echo "selinux        $(getenforce 2>/dev/null || echo n/a)"
    echo "session_type   ${XDG_SESSION_TYPE:-none}"
    orbit=/opt/orbit/bin/orbit/linux/stable/orbit; osq=/opt/orbit/bin/osqueryd/linux/stable/osqueryd ;;
esac
# fleetd paths are the defaults. A missing line means fleetd is not installed there, or is installed somewhere else.
[ -x "$orbit" ] && echo "orbit          $("$orbit" --version 2>&1 | head -1)" || echo "orbit          not found at default path"
[ -x "$osq" ]   && echo "osqueryd       $("$osq" --version 2>&1 | head -1)" || echo "osqueryd       not found at default path"
echo "tools          $(for t in curl jq python3 docker ssh; do command -v $t >/dev/null && printf '%s ' $t; done)"
# Clock check input: compare with the Fleet server's Date header (bin/clock-check.sh) before timed tests.
echo "clock_synced   $(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo n/a)"
