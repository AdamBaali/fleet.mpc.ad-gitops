#!/bin/bash
# Runs export-fleet-hosts-for-duo.sh against mock_fleet.py and checks the output.
# Usage: tests/test_export_script.sh <path-to-export-fleet-hosts-for-duo.sh>
set -uo pipefail

command -v timeout >/dev/null || timeout() { shift; "$@"; } # macOS has no GNU timeout.

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
check "failed run leaves no windows.csv behind" 0 "$(ls "$WORK/fail"/*.csv 2>/dev/null | grep -c windows)"
check "failed run leaves no temp folder" 0 "$(ls -A "$WORK/fail" | grep -c duo-export)"

# A failed run must not touch files from the previous run.
mkdir -p "$WORK/keep"; printf 'device_id\nOLD-1\nOLD-2\n' >"$WORK/keep/windows.csv"
(cd "$WORK/keep" && FLEET_API_TOKEN=x timeout 60 "$WORK/export404.sh" >/dev/null 2>&1)
check "failed run keeps previous windows.csv" "OLD-2" "$(tail -1 "$WORK/keep/windows.csv")"

# Shrink guard: previous list had 10,000 Windows IDs, the new one has 2.
mkdir -p "$WORK/shrink"; (echo device_id; seq 1 10000) >"$WORK/shrink/windows.csv"
(cd "$WORK/shrink" && FLEET_API_TOKEN=x timeout 60 "$WORK/export.sh" >/dev/null 2>"$WORK/shrink.err")
rc=$?; [ $rc -ne 0 ] && rc=nonzero
check "shrink guard exits non-zero" nonzero "$rc"
check "shrink guard keeps previous windows.csv" 10000 "$(count "$WORK/shrink/windows.csv")"
check "shrink guard doesn't replace macos.csv" 0 "$(ls "$WORK/shrink"/macos.csv 2>/dev/null | wc -l | tr -d ' ')"
check "shrink guard names the file" 1 "$(grep -c 'windows.csv' "$WORK/shrink.err")"
(cd "$WORK/shrink" && FORCE=true FLEET_API_TOKEN=x timeout 60 "$WORK/export.sh" >/dev/null 2>&1)
check "FORCE=true replaces the list" 2 "$(count "$WORK/shrink/windows.csv")"

# A list that shrinks by less than half is accepted.
mkdir -p "$WORK/small"; (echo device_id; seq 1 3) >"$WORK/small/windows.csv"
(cd "$WORK/small" && FLEET_API_TOKEN=x timeout 60 "$WORK/export.sh" >/dev/null 2>&1)
check "small shrink accepted" 2 "$(count "$WORK/small/windows.csv")"

command -v shellcheck >/dev/null && { shellcheck "$SCRIPT" && echo "PASS shellcheck" || { echo "FAIL shellcheck"; fails=$((fails + 1)); }; }

echo; [ $fails -eq 0 ] && echo "All checks passed" || echo "$fails check(s) failed"
exit $fails
