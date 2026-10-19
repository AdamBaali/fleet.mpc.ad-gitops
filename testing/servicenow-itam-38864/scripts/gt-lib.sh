#!/usr/bin/env bash
# Ground truth recorder shared by gt-macos.sh and gt-linux.sh (fleetdm/fleet#38864).
# Every action a test depends on (install, open, upgrade, reinstall, uninstall) is written here with
# its UTC time at the moment it happens, before anyone looks at Fleet. compare.py reads these files.
GT_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GT_DIR="${GT_DIR:-$GT_HERE/../ground-truth}"
GT_HOST="${GT_HOST:-$(hostname -s 2>/dev/null || hostname)}"
GT_FILE="$GT_DIR/$GT_HOST.tsv"

gt_init() {
  mkdir -p "$GT_DIR"
  [ -s "$GT_FILE" ] || printf 'test_id\thost\tos\tapp\tkey\tversion\tmethod\tevent\tutc\texpected_publisher\tnote\n' > "$GT_FILE"
}

# gt_record <test_id> <os> <app> <key> <version> <method> <event> [expected_publisher] [note]
gt_record() {
  gt_init
  local utc; utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$GT_HOST" "$2" "$3" "$4" "$5" "$6" "$7" "$utc" "${8:-}" "${9:-}" >> "$GT_FILE"
  echo "recorded $7 $3 at $utc -> $GT_FILE"
}

# gt_wait_for <path> [timeout_seconds]   polls until a path exists. For installs started elsewhere
# (Fleet, App Store) the record is the moment the app arrives on disk.
gt_wait_for() {
  local p="$1" t="${2:-1800}" waited=0
  while [ ! -e "$p" ]; do
    [ "$waited" -ge "$t" ] && { echo "timed out waiting for $p" >&2; return 1; }
    sleep 5; waited=$((waited + 5))
  done
}
