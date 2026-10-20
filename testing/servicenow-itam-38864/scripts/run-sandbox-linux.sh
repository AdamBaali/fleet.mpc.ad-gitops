#!/usr/bin/env bash
# Linux sandbox run of the ITAM tests that need no Fleet server (fleetdm/fleet#38864).
#
# Usage: sudo OSQ=/path/to/osqueryd GT_HOST=<name> ./run-sandbox-linux.sh
#   OSQ      osqueryd binary to use in shell mode (fleetd's own on a real host)
#   GT_HOST  host label for ground truth and evidence (default: hostname)
#
# Runs on a disposable Ubuntu or Fedora host or container as root. It installs and removes the
# test package, writes /etc/osquery/extensions.load and /var/osquery/extensions. Don't run it on
# a host you care about.
#
# Why shims for systemctl and systemd-run: a container has no fleetd service. The shims log what
# the installer asked for, so the run checks the restart is scheduled without restarting anything.
# Everything else is real: the pinned download, the checksum, the autoload file, osquery loading
# the extension from that file, the package manager, and the ground truth.
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

INSTALLER="$ROOT/lib/linux/scripts/install-software-itam-extension.sh"
REPORTS="$ROOT/lib/linux/reports/software-itam.reports.yml"
EXT_PATH=/var/osquery/extensions/software_itam.ext
LOADER=/etc/osquery/extensions.load
export PKG="${PKG:-hello}"

if command -v apt-get >/dev/null; then SRC=deb; NCOL=list_changed; PCOL=maintainer; TI=L-2
  NATIVE='ITAM Linux DEB install date and maintainer'
else SRC=rpm; NCOL=install_time; PCOL=vendor; TI=L-1
  NATIVE='ITAM Linux RPM install date and vendor'; fi
export SRC NCOL

# The report SQL exactly as Fleet sends it, from the repo's YAML.
NATIVE_SQL="$(awk -v want="$NATIVE" '
  /^- name: / { inq = 0; name = substr($0, 9); next }
  name == want && /^  query: \|/ { inq = 1; next }
  inq && /^    / { sub(/^    /, ""); printf "%s ", $0; next }
  inq { inq = 0 }' "$REPORTS")"
export NATIVE_SQL

# Shims: record what the installer asks of systemd.
SHIM="$W/shim"; mkdir -p "$SHIM"
cat > "$SHIM/systemctl" <<'EOF'
#!/bin/sh
echo "systemctl $*" >> "$SHIM_LOG"
case "$1 $2" in "cat orbit.service") exit 0 ;; esac
exit 0
EOF
cat > "$SHIM/systemd-run" <<'EOF'
#!/bin/sh
echo "systemd-run $*" >> "$SHIM_LOG"
exit 0
EOF
chmod +x "$SHIM/systemctl" "$SHIM/systemd-run"
export SHIM SHIM_LOG="$W/systemd-calls.log"

# q <label> <sql>: osquery shell mode with the extension autoloaded from the default file,
# as osqueryd under fleetd loads it. extensions_require makes the query wait for registration.
q() {
  "$OSQ" -S --json --extensions_require=software_itam --extensions_timeout=20 "$2" > "$W/$1.json" 2> "$W/$1.err"
  echo "rows=$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$W/$1.json" 2>/dev/null || echo error) -> $1.json"
}
snap() { # <label>: native report and extension rows for the test package right now
  q "native-$1" "$NATIVE_SQL"
  q "ext-$1" "SELECT * FROM software_itam;"
  python3 - "$W/native-$1.json" "$W/ext-$1.json" <<'PY'
import json, os, sys
pkg = os.environ['PKG']
for f in sys.argv[1:]:
    rows = [r for r in json.load(open(f)) if r.get('name') == pkg]
    print(os.path.basename(f), json.dumps(rows, sort_keys=True))
PY
}
export -f q snap

verdict() { # id ok-exit-code pass-note fail-note
  if [ "$2" -eq 0 ]; then ev_verdict "$1" PASS "$3"; else ev_verdict "$1" FAIL "$4"; fi
}

# Start clean: no extension, no state file, no loader line, test package absent.
rm -rf /var/osquery/extensions
[ -f "$LOADER" ] && sed -i "\#$EXT_PATH#d" "$LOADER"
if [ "$SRC" = deb ]; then apt-get remove -y -q "$PKG" >/dev/null 2>&1 || true; else dnf remove -y -q "$PKG" >/dev/null 2>&1 || true; fi

# ---- S-0 facts ----
ev_init S-0 "Sandbox facts" "Record the environment these results come from" "Facts saved" >/dev/null
ev_cmd S-0 os-release "grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release; uname -m"
ev_cmd S-0 osquery-version "$OSQ --version"
ev_cmd S-0 prior-installs "grep -h ' install $PKG' /var/log/dpkg.log* 2>/dev/null || echo 'no earlier $PKG install in dpkg.log'"
ev_cmd S-0 mounts "findmnt -no TARGET,FSTYPE,OPTIONS / 2>/dev/null || cat /proc/mounts | head -5"
ev_note S-0 "No fleetd or Fleet server here. osquery runs in shell mode (osqueryd -S), the extension is the pinned build, and the package manager is real. systemctl and systemd-run are shims that log calls."
ev_verdict S-0 INFO "Environment recorded"

# ---- X-1 installer ----
ev_init X-1 "Installer: download, checksum, autoload file" "Run the real Linux installer" "Exit 0, binary matches the pinned SHA-256, path listed once in /etc/osquery/extensions.load, root-owned 0755, restart scheduled" >/dev/null
ev_cmd X-1 first-run "PATH=$SHIM:\$PATH SHIM_LOG=$SHIM_LOG sh $INSTALLER; echo exit=\$?"
want="$(sed -n "s/^SHA256_AMD64='\(.*\)'/\1/p" "$INSTALLER")"
[ "$(uname -m)" = aarch64 ] && want="$(sed -n "s/^SHA256_ARM64='\(.*\)'/\1/p" "$INSTALLER")"
ev_cmd X-1 placed "sha256sum $EXT_PATH; stat -c '%U:%G %a %n' /var/osquery /var/osquery/extensions $EXT_PATH $LOADER; cat $LOADER; cat $SHIM_LOG"
ok=1
[ "$(sha256sum "$EXT_PATH" | awk '{print $1}')" = "$want" ] && [ "$(grep -cxF "$EXT_PATH" "$LOADER")" -eq 1 ] \
  && [ "$(stat -c '%U %a' "$EXT_PATH")" = "root 755" ] && grep -q '^systemd-run --on-active=30' "$SHIM_LOG" && ok=0
verdict X-1 $ok "Installed the pinned build, listed once in $LOADER, restart scheduled through systemd-run" "One of checksum, loader line, ownership or restart schedule is wrong. See outputs"

ev_init X-1b "Installer: second run changes nothing" "Re-run the installer" "Already current, loader still has one line, no new restart" >/dev/null
before="$(wc -l < "$SHIM_LOG")"
ev_cmd X-1b second-run "PATH=$SHIM:\$PATH SHIM_LOG=$SHIM_LOG sh $INSTALLER; echo exit=\$?"
ok=1
[ "$(grep -cxF "$EXT_PATH" "$LOADER")" -eq 1 ] && ! tail -n +"$((before + 1))" "$SHIM_LOG" | grep -q systemd-run && ok=0
verdict X-1b $ok "Idempotent: nothing downloaded, no duplicate loader line, no restart" "Second run changed state"

ev_init X-1c "Installer: wrong checksum is refused" "Run a copy of the installer with a wrong SHA-256" "Exit 6, installed binary unchanged" >/dev/null
sed "s/^SHA256_AMD64='.*'/SHA256_AMD64='$(printf '0%.0s' $(seq 64))'/; s/^SHA256_ARM64='.*'/SHA256_ARM64='$(printf '0%.0s' $(seq 64))'/" "$INSTALLER" > "$W/installer-bad-sha.sh"
ev_cmd X-1c bad-sha "PATH=$SHIM:\$PATH SHIM_LOG=$SHIM_LOG sh $W/installer-bad-sha.sh; echo exit=\$?"
ok=1
grep -q '^exit=6' "$(ls "$EV"/X-1c-*/01-bad-sha.txt)" && [ "$(sha256sum "$EXT_PATH" | awk '{print $1}')" = "$want" ] && ok=0
verdict X-1c $ok "Checksum mismatch refused with exit 6, good binary left in place" "Bad checksum was not refused"

# ---- X-2 autoload and columns ----
ev_init X-2 "Table registered from the default autoload file" "Load the extension the way osqueryd does under fleetd: no --extension flag" "software_itam active with every documented column" >/dev/null
ev_cmd X-2 registry "$OSQ -S --json --extensions_require=software_itam --extensions_timeout=20 \"SELECT name, active, internal FROM osquery_registry WHERE registry = 'table' AND name = 'software_itam';\""
ev_cmd X-2 columns "$OSQ -S --json --extensions_require=software_itam --extensions_timeout=20 \"SELECT name, type FROM pragma_table_info('software_itam');\""
ok=0
grep -qE '"active": ?"1"' "$(ls "$EV"/X-2-*/01-registry.txt)" || ok=1
for c in source name version identifier path arch publisher publisher_source install_date install_date_source install_date_candidates first_seen; do
  grep -qE "\"name\": ?\"$c\"" "$(ls "$EV"/X-2-*/02-columns.txt)" || ok=1
done
verdict X-2 $ok "Autoloaded from $LOADER with all 12 columns" "Not autoloaded or a column is missing"

# ---- Install the test package ----
ev_init "$TI" "Install date: $SRC package" "Install $PKG with the package manager, read the native report and software_itam" "Native and extension install dates within 2 minutes of the recorded install" >/dev/null
ev_cmd "$TI" install "$SDIR/gt-linux.sh install"
sleep 2
ev_cmd "$TI" rows-after-install "snap install"
ev_cmd "$TI" check "python3 $SDIR/sandbox_check.py date $GT install $PKG $W/native-install.json $NCOL $W/ext-install.json"
grep -q 'native: match' "$(ls "$EV/$TI"-*/03-check.txt)" && grep -q 'ext: match' "$(ls "$EV/$TI"-*/03-check.txt)"; ok=$?
verdict "$TI" $ok "Native $NCOL and extension install_date both match the recorded install" "A date missed the recorded install. See check output"

ev_init X-5 "Publisher: $SRC package" "Compare the extension publisher to the package metadata" "Same company or maintainer as the package manager shows" >/dev/null
ev_cmd X-5 check "python3 $SDIR/sandbox_check.py publisher $GT $PKG $W/ext-install.json"
python3 "$SDIR/sandbox_check.py" publisher "$GT" "$PKG" "$W/ext-install.json" >/dev/null; ok=$?
verdict X-5 $ok "Publisher matches the package metadata" "Publisher differs from the package metadata"

# ---- Coverage over the whole host ----
ev_init X-3 "Rows and coverage: native against extension" "Count rows, install dates and publishers on the whole host" "Row counts within 5%. Coverage recorded for C-1 and C-2" >/dev/null
ev_cmd X-3 coverage "python3 $SDIR/sandbox_check.py coverage $W/native-install.json $NCOL $PCOL $W/ext-install.json ${SRC}_packages"
python3 "$SDIR/sandbox_check.py" coverage "$W/native-install.json" "$NCOL" "$PCOL" "$W/ext-install.json" "${SRC}_packages" >/dev/null; ok=$?
verdict X-3 $ok "Extension row count within 5% of the native inventory. Coverage in the output" "Row counts differ by more than 5%"

# ---- X-8 first_seen across restarts ----
ev_init X-8 "first_seen survives an osquery restart" "Read first_seen in two separate osquery processes" "Same value for every row" >/dev/null
sleep 2
ev_cmd X-8 second-process "snap restart"
ev_cmd X-8 compare "python3 -c \"import json; a={(r['source'],r['identifier'],r['path']):r['first_seen'] for r in json.load(open('$W/ext-install.json'))}; b={(r['source'],r['identifier'],r['path']):r['first_seen'] for r in json.load(open('$W/ext-restart.json'))}; d=[k for k in a if k in b and a[k]!=b[k]]; print('rows', len(a), 'changed', len(d)); raise SystemExit(1 if d or not a else 0)\""
grep -q '^\[exit 0\]' "$(ls "$EV"/X-8-*/02-compare.txt)"; ok=$?
verdict X-8 $ok "first_seen identical across two processes for every row. Reboot not tested in a container" "first_seen changed between processes"

# ---- X-9 cost ----
ev_init X-9 "Cost of one software_itam query" "Time a full query" "Seconds, not minutes" >/dev/null
ev_cmd X-9 timing "/usr/bin/time -v $OSQ -S --json --extensions_require=software_itam --extensions_timeout=20 'SELECT COUNT(*) AS n FROM software_itam;' 2>&1 | grep -E '\"n\"|Elapsed|Maximum resident' || (time $OSQ -S --json --extensions_require=software_itam --extensions_timeout=20 'SELECT COUNT(*) AS n FROM software_itam;')"
ev_verdict X-9 INFO "Timing recorded in the output. Watchdog limits only apply under fleetd"

# ---- Upgrade ----
ev_init L-2u "Upgrade or reinstall: which dates move" "Upgrade $PKG (downgrade then upgrade, or reinstall when the repo has one version)" "Native moves to the upgrade. Extension keeps the first install for DEB (dpkg.log), moves for RPM" >/dev/null
ev_cmd L-2u upgrade "$SDIR/gt-linux.sh upgrade"
sleep 2
ev_cmd L-2u rows-after-upgrade "snap upgrade"
if [ "$SRC" = deb ]; then expect=first; else expect=event; fi
ev_cmd L-2u check "python3 $SDIR/sandbox_check.py date $GT upgrade $PKG $W/native-upgrade.json $NCOL $W/ext-upgrade.json --ext-expect $expect"
python3 "$SDIR/sandbox_check.py" date "$GT" upgrade "$PKG" "$W/native-upgrade.json" "$NCOL" "$W/ext-upgrade.json" --ext-expect "$expect" >/dev/null; ok=$?
verdict L-2u $ok "Native moved to the upgrade time. Extension install_date followed the expected rule ($expect)" "A date didn't follow the expected rule. See check output"

# ---- Uninstall ----
ev_init U-2 "Uninstall drops the rows" "Remove $PKG, read both again" "No row in the native report or software_itam" >/dev/null
ev_cmd U-2 uninstall "$SDIR/gt-linux.sh uninstall"
sleep 2
ev_cmd U-2 rows-after-uninstall "snap uninstall"
python3 "$SDIR/sandbox_check.py" absent "$PKG" "$W/native-uninstall.json" "$W/ext-uninstall.json" >/dev/null; ok=$?
ev_cmd U-2 check "python3 $SDIR/sandbox_check.py absent $PKG $W/native-uninstall.json $W/ext-uninstall.json"
verdict U-2 $ok "Both rows gone at the next query" "A row is still present after uninstall"

# ---- Reinstall ----
ev_init X-7 "Reinstall: install date and first_seen" "Install $PKG again" "first_seen keeps the first sighting. DEB install_date keeps the first install from dpkg.log, RPM moves" >/dev/null
fs_before="$(python3 -c "import json,os; print(next((r['first_seen'] for r in json.load(open('$W/ext-install.json')) if r['name']==os.environ['PKG']), ''))")"
ev_cmd X-7 reinstall "$SDIR/gt-linux.sh reinstall"
sleep 2
ev_cmd X-7 rows-after-reinstall "snap reinstall"
ev_cmd X-7 check "python3 $SDIR/sandbox_check.py date $GT reinstall $PKG $W/native-reinstall.json $NCOL $W/ext-reinstall.json --ext-expect $expect; echo first_seen_before=$fs_before"
fs_after="$(python3 -c "import json,os; print(next((r['first_seen'] for r in json.load(open('$W/ext-reinstall.json')) if r['name']==os.environ['PKG']), ''))")"
python3 "$SDIR/sandbox_check.py" date "$GT" reinstall "$PKG" "$W/native-reinstall.json" "$NCOL" "$W/ext-reinstall.json" --ext-expect "$expect" >/dev/null && [ -n "$fs_before" ] && [ "$fs_before" = "$fs_after" ]; ok=$?
verdict X-7 $ok "first_seen kept ($fs_before). install_date followed the $expect rule" "first_seen ($fs_before -> $fs_after) or install_date didn't follow the rule"

# ---- L-3 facts only ----
ev_init L-3 "Last used: facts" "Record what Fleet's built-in last_opened_at depends on" "Mount options and osquery version saved. The value itself needs a Fleet server" >/dev/null
ev_cmd L-3 facts "$SDIR/gt-linux.sh facts; $OSQ --version"
ev_verdict L-3 NOT-RUN "Built-in last_opened_at is computed by the Fleet server. Facts saved for the real host run"

rm -rf "$W/shim"
cut -f1,2,4 "$EV/results.tsv"
