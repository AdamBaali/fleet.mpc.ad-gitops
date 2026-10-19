#!/usr/bin/env bash
# On-host truth for the ITAM tests (S-1, M-5, X-2, X-3, C-*). Run with sudo on a macOS or Linux test host
# from a checkout of this repo.
#
# Usage: sudo ./host-local-check.sh [out_dir]
# Runs every report in lib/<os>/reports/software-itam.reports.yml and `SELECT * FROM software_itam`
# with fleetd's own osqueryd in shell mode, so the rows match what Fleet would get. Writes one JSON
# file per query plus timings to out_dir (default ../test-evidence/local/<host>).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

case "$(uname -s)" in
  Darwin) OS=macos; LOADER=/var/osquery/extensions.load
          OSQ="$(ls /opt/orbit/bin/osqueryd/macos-app/*/osquery.app/Contents/MacOS/osqueryd 2>/dev/null | head -1)" ;;
  Linux)  OS=linux; LOADER=/etc/osquery/extensions.load
          OSQ="$(ls /opt/orbit/bin/osqueryd/linux*/*/osqueryd 2>/dev/null | head -1)" ;;
  *) echo "unsupported OS" >&2; exit 1 ;;
esac
[ -x "${OSQ:-}" ] || OSQ="$(command -v osqueryi || true)"
[ -n "$OSQ" ] || { echo "no osqueryd under /opt/orbit and no osqueryi on PATH" >&2; exit 1; }

OUT="${1:-$HERE/../test-evidence/local/$(hostname -s)}"
mkdir -p "$OUT"
REPORTS="$ROOT/lib/$OS/reports/software-itam.reports.yml"

# Extension path from the default autoload file the installer writes to.
EXT="$(grep -m1 software_itam "$LOADER" 2>/dev/null || true)"

# Prints "name<TAB>sql" per report. The YAML is the repo's own: "- name:" items with a "query: |" block.
extract() {
  awk '
    /^- name: / { if (name != "") print name "\t" q; name = substr($0, 9); q = ""; inq = 0; next }
    /^  query: \|/ { inq = 1; next }
    inq && /^    / { sub(/^    /, ""); q = q " " $0; next }
    inq && !/^    / { inq = 0 }
    END { if (name != "") print name "\t" q }
  ' "$1"
}

run() { # label sql
  local f; f="$OUT/$(echo "$1" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9-').json"
  local args=(-S --json)
  [ -n "$EXT" ] && args+=(--extension "$EXT" --allow_unsafe)
  local t0 t1; t0=$(date +%s)
  "$OSQ" "${args[@]}" "$2" > "$f" 2> "$f.err" || true
  t1=$(date +%s)
  printf '%-50s rows=%-6s seconds=%s %s\n' "$1" "$(grep -c '^  {' "$f" || true)" "$((t1 - t0))" "$( [ -s "$f.err" ] && echo "stderr: $(head -c 200 "$f.err")")"
}

echo "osqueryd: $OSQ"
"$OSQ" -S --json "SELECT version FROM osquery_info;" 2>/dev/null | tr -d '\n '; echo
while IFS=$'\t' read -r name sql; do run "$name" "$sql"; done < <(extract "$REPORTS")
if [ -n "$EXT" ]; then
  run "ITAM software (extension)" "SELECT * FROM software_itam;"
else
  echo "software_itam extension not listed in $LOADER: extension checks skipped"
fi
# Native inventory counts, for the X-3 row count comparison.
if [ "$OS" = macos ]; then run "native apps count" "SELECT COUNT(*) AS n FROM apps;"
else run "native rpm count" "SELECT COUNT(*) AS n FROM rpm_packages;"; run "native deb count" "SELECT COUNT(*) AS n FROM deb_packages;"; fi
echo "outputs in $OUT"
