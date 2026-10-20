#!/usr/bin/env bash
# Linux sandbox run of the native report tests that need no Fleet server (fleetdm/fleet#38864).
#
# Usage: sudo OSQ=/path/to/osqueryd GT_HOST=<name> ./run-sandbox-linux.sh
#   OSQ      osqueryd binary to use in shell mode (fleetd's own on a real host)
#   GT_HOST  host label for ground truth and evidence (default: hostname)
#
# Runs on a disposable Ubuntu or Fedora host or container as root. It installs, upgrades and removes
# the test package. Don't run it on a host you care about.
#
# Real: the report SQL from the repo's YAML, osquery, the package manager and the ground truth.
# Not covered: Fleet ingestion, the API and the exporter, since there is no Fleet server here.
set -uo pipefail
# SDIR, not HERE: ev.sh sets HERE to its own folder when sourced.
SDIR="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(cd "$SDIR/.." && pwd)"
ROOT="$(cd "$PROJ/../.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
: "${OSQ:?set OSQ to an osqueryd binary}"
export OSQ
export GT_HOST="${GT_HOST:-$(hostname -s 2>/dev/null || hostname)}"
export EV="$PROJ/test-evidence/sandbox-$GT_HOST"
export GT="$PROJ/ground-truth/$GT_HOST.tsv"
export W="$EV/_work"
rm -rf "$EV" && mkdir -p "$W"
rm -f "$GT"
# shellcheck source=/dev/null
. "$ROOT/testing/_framework/bin/ev.sh"

REPORTS="$ROOT/lib/linux/reports/software-itam.reports.yml"
export PKG="${PKG:-hello}"

if command -v apt-get >/dev/null; then SRC=deb; NCOL=list_changed; PCOL=maintainer; TI=L-2
  NATIVE='ITAM Linux DEB install date and maintainer'
else SRC=rpm; NCOL=install_time; PCOL=vendor; TI=L-1
  NATIVE='ITAM Linux RPM install date and vendor'; fi

# The report SQL exactly as Fleet sends it, from the repo's YAML.
NATIVE_SQL="$(awk -v want="$NATIVE" '
  /^- name: / { inq = 0; name = substr($0, 9); next }
  name == want && /^  query: \|/ { inq = 1; next }
  inq && /^    / { sub(/^    /, ""); printf "%s ", $0; next }
  inq { inq = 0 }' "$REPORTS")"
export NATIVE_SQL

snap() { # <label>: the native report now, plus the test package's row
  "$OSQ" -S --json "$NATIVE_SQL" > "$W/native-$1.json" 2> "$W/native-$1.err"
  python3 - "$W/native-$1.json" <<'PY'
import json, os, sys
rows = json.load(open(sys.argv[1]))
print('rows=%d' % len(rows))
print(json.dumps([r for r in rows if r.get('name') == os.environ['PKG']], sort_keys=True))
PY
}
export -f snap

verdict() { # id exit-code pass-note fail-note
  if [ "$2" -eq 0 ]; then ev_verdict "$1" PASS "$3"; else ev_verdict "$1" FAIL "$4"; fi
}
check() { # id label args...: run sandbox_check.py as evidence, return its exit code
  local id="$1" label="$2"; shift 2
  ev_cmd "$id" "$label" "python3 $SDIR/sandbox_check.py $*"
  python3 "$SDIR/sandbox_check.py" "$@" >/dev/null
}

# Start clean: test package absent.
if [ "$SRC" = deb ]; then apt-get remove -y -q "$PKG" >/dev/null 2>&1 || true; else dnf remove -y -q "$PKG" >/dev/null 2>&1 || true; fi

# ---- S-0 facts ----
ev_init S-0 "Sandbox facts" "Record the environment these results come from" "Facts saved" >/dev/null
ev_cmd S-0 os-release "grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release; uname -m"
ev_cmd S-0 osquery-version "$OSQ --version"
ev_cmd S-0 prior-installs "grep -h ' install $PKG' /var/log/dpkg.log* 2>/dev/null || echo 'no earlier $PKG install in dpkg.log'"
ev_cmd S-0 report-sql "printf '%s\n' \"\$NATIVE_SQL\""
ev_note S-0 "No fleetd or Fleet server here. osquery runs the report SQL from the repo in shell mode (osqueryd -S). The package manager is real."
ev_verdict S-0 INFO "Environment recorded"

# ---- Install ----
ev_init "$TI" "Install date and publisher: $SRC package" "Install $PKG, run the native report" "$NCOL within 2 minutes of the recorded install. Publisher matches the package metadata" >/dev/null
ev_cmd "$TI" install "$SDIR/gt-linux.sh install"
sleep 2
ev_cmd "$TI" rows-after-install "snap install"
check "$TI" date-check date "$GT" install "$PKG" "$W/native-install.json" "$NCOL"; d=$?
check "$TI" publisher-check publisher "$GT" "$PKG" "$W/native-install.json" "$PCOL"; p=$?
verdict "$TI" $((d + p)) "$NCOL matched the recorded install. Publisher matched the package metadata" "Date or publisher missed. See the check outputs"

# ---- Coverage over the whole host ----
ev_init S-0c "Report coverage on the whole host" "Count rows with an install date and a publisher" "Coverage recorded" >/dev/null
check S-0c coverage coverage "$W/native-install.json" "$NCOL" "$PCOL"
ev_verdict S-0c INFO "Coverage recorded in the output"

# ---- Upgrade, then reinstall: which date the report keeps ----
ev_init "${TI}u" "Upgrade and reinstall: what $NCOL shows" "Upgrade $PKG (downgrade then upgrade, or reinstall when the repo has one version), then reinstall" "$NCOL moves to the latest change each time, so it is not a first install date" >/dev/null
ev_cmd "${TI}u" upgrade "$SDIR/gt-linux.sh upgrade"
sleep 2
ev_cmd "${TI}u" rows-after-upgrade "snap upgrade"
check "${TI}u" upgrade-check date "$GT" upgrade "$PKG" "$W/native-upgrade.json" "$NCOL"; a=$?
ev_cmd "${TI}u" uninstall "$SDIR/gt-linux.sh uninstall"
sleep 2
ev_cmd "${TI}u" reinstall "$SDIR/gt-linux.sh reinstall"
sleep 2
ev_cmd "${TI}u" rows-after-reinstall "snap reinstall"
check "${TI}u" reinstall-check date "$GT" reinstall "$PKG" "$W/native-reinstall.json" "$NCOL"; b=$?
verdict "${TI}u" $((a + b)) "$NCOL moved to the upgrade, then to the reinstall. Label it last changed and use first seen for first installed" "$NCOL did not follow the latest change. See the check outputs"

# ---- Uninstall ----
ev_init U-2 "Uninstall drops the row" "Remove $PKG, run the report" "No row for $PKG" >/dev/null
ev_cmd U-2 uninstall "$SDIR/gt-linux.sh uninstall"
sleep 2
ev_cmd U-2 rows-after-uninstall "snap uninstall"
check U-2 absent-check absent "$PKG" "$W/native-uninstall.json"; u=$?
verdict U-2 $u "Row gone at the next run" "Row still present after uninstall"

# ---- L-3 facts only ----
ev_init L-3 "Last used: facts" "Record what Fleet's built-in last_opened_at depends on" "Mount options and osquery version saved. The value itself needs a Fleet server" >/dev/null
ev_cmd L-3 facts "$SDIR/gt-linux.sh facts; $OSQ --version"
ev_verdict L-3 NOT-RUN "Built-in last_opened_at is computed by the Fleet server. Facts saved for the real host run"

cut -f1,2,4 "$EV/results.tsv"
