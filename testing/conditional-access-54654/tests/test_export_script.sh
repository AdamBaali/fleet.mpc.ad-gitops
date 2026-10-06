#!/bin/bash
# Runs export-fleet-hosts-for-duo.sh against mock_fleet.py and checks the output.
# Usage: tests/test_export_script.sh <path-to-export-fleet-hosts-for-duo.sh>
set -uo pipefail

SCRIPT="${1:?Pass the path to export-fleet-hosts-for-duo.sh}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
fails=0

python3 "$HERE/mock_fleet.py" >/dev/null 2>&1 &
MOCK=$!
trap 'kill $MOCK 2>/dev/null; rm -rf "$WORK"' EXIT
sleep 1

sed -e 's#https://fleet.example.com#http://127.0.0.1:8899#' \
    -e 's#<Windows-MachineGuid-report-ID>#42#' "$SCRIPT" >"$WORK/export.sh"
chmod +x "$WORK/export.sh"

check() { # name, expected, actual
  if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1 (expected $2, got $3)"; fails=$((fails + 1)); fi
}
count() { echo $(($(wc -l <"$1") - 1)); }

for mode in false true; do
  out="$WORK/$mode"; mkdir -p "$out"
  (cd "$out" && FLEET_API_TOKEN=x REQUIRE_PASSING_CRITICAL_POLICIES=$mode timeout 60 "$WORK/export.sh" >/dev/null)
  check "require=$mode exits 0" 0 $?
  check "require=$mode header" device_id "$(head -1 "$out/macos.csv")"
  check "require=$mode no iOS/Chrome in linux.csv" 0 "$(grep -cE 'IOS|CHROME' "$out/linux.csv")"
  check "require=$mode deleted host dropped" 0 "$(grep -c guid-deleted "$out/windows.csv")"
  check "require=$mode Windows guids unique" "$(sort "$out/windows.csv" | uniq | wc -l)" "$(wc -l <"$out/windows.csv")"
  check "require=$mode linux count" 2 "$(count "$out/linux.csv")"
done
check "trust-all macOS count (pagination)" 1102 "$(count "$WORK/false/macos.csv")"
check "trust-all Windows count" 2 "$(count "$WORK/false/windows.csv")"
check "critical-only macOS count" 1101 "$(count "$WORK/true/macos.csv")"
check "critical-only Windows count" 1 "$(count "$WORK/true/windows.csv")"

# Failure mode: report fetch fails. Script must exit non-zero.
sed 's#reports/\$WINDOWS_REPORT_ID#reports/999#' "$WORK/export.sh" >"$WORK/export404.sh"; chmod +x "$WORK/export404.sh"
mkdir -p "$WORK/fail"; (cd "$WORK/fail" && FLEET_API_TOKEN=x timeout 60 "$WORK/export404.sh" >/dev/null 2>&1)
rc=$?; [ $rc -ne 0 ] && rc=nonzero
check "report failure exits non-zero" nonzero "$rc"
echo "INFO windows.csv after failed run has $(wc -l <"$WORK/fail/windows.csv" 2>/dev/null || echo 0) lines (0 = truncated, see guide issue on empty uploads)"

command -v shellcheck >/dev/null && { shellcheck "$SCRIPT" && echo "PASS shellcheck" || { echo "FAIL shellcheck"; fails=$((fails + 1)); }; }

echo; [ $fails -eq 0 ] && echo "All checks passed" || echo "$fails check(s) failed"
exit $fails
