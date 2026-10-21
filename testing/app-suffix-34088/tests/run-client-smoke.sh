#!/usr/bin/env bash
# Runs every script in sql/ through the mysql command-line client, the way
# the customer will, against Fleet's schema in Fleet's mysql_test container.
# Catches what the Go test can't: client defaults (MySQL 8 connects with
# utf8mb4_0900_ai_ci), stop-on-error behavior, and GTID consistency rules.
# Usage: tests/run-client-smoke.sh <path-to-fleet-checkout>
# Output: test-evidence/client/<fleet tag or main-sha>/
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
fleet="$(cd "${1:?path to a fleet checkout}" && pwd)"
ref="$(git -C "$fleet" describe --tags --exact-match 2>/dev/null || echo "main-$(git -C "$fleet" rev-parse --short HEAD)")"
out="$here/test-evidence/client/$ref"
db=app_suffix_smoke

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-fleet-app-suffix}"
(cd "$fleet" && docker compose up -d mysql_test >/dev/null)
c="$(cd "$fleet" && docker compose ps -q mysql_test)"
for _ in $(seq 1 60); do docker exec "$c" mysql -uroot -ptoor -e "SELECT 1" >/dev/null 2>&1 && break; sleep 2; done

# The mysql client warns about a password on the command line. Drop that line
# and keep the client's exit code.
my() {
  local rc=0 tmp
  tmp="$(mktemp)"
  docker exec -i "$c" mysql -uroot -ptoor --default-character-set=utf8mb4 --table "$@" > "$tmp" 2>&1 || rc=$?
  grep -v "Using a password" "$tmp" || true
  rm -f "$tmp"
  return "$rc"
}

rm -rf "$out" && mkdir -p "$out"
{
  echo "# fleet: $ref"
  echo "# server: $(my --skip-table -N -B -e "SELECT CONCAT(VERSION(), ', gtid_mode=', @@gtid_mode, ', enforce_gtid_consistency=', @@enforce_gtid_consistency, ', binlog_format=', @@binlog_format)")"
  echo "# client connection collation: $(my --skip-table -N -B -e 'SELECT @@collation_connection')"
} > "$out/run.txt"

my -e "DROP DATABASE IF EXISTS $db; CREATE DATABASE $db"
# Same as Fleet's test helper (LoadSchema): schema.sql creates tables before the ones they reference.
{ echo "SET FOREIGN_KEY_CHECKS=0;"; cat "$fleet/server/datastore/mysql/schema.sql"; } | my "$db" > /dev/null
my "$db" < "$here/tests/fixture-client.sql"

run() { # label, file
  set +e; my "$db" < "$2" > "$out/$1.txt"; rc=$?; set -e
  echo "$1: exit $rc" | tee -a "$out/run.txt"
}

# The bug this guards against: without SET NAMES, MySQL 8's default client
# collation can't be compared with Fleet's columns.
grep -v '^SET NAMES' "$here/sql/2_plan.sql" > "$out/2_plan-without-set-names.sql"
run 0_plan_without_set_names "$out/2_plan-without-set-names.sql"
rm "$out/2_plan-without-set-names.sql"

run 1_diagnose "$here/sql/1_diagnose.sql"
run 2_plan "$here/sql/2_plan.sql"
run 3_apply_batch_1 "$here/sql/3_apply_batch.sql"
run 3_apply_batch_2 "$here/sql/3_apply_batch.sql"
run 4_titles "$here/sql/4_titles.sql"
run 5_verify "$here/sql/5_verify.sql"
my "$db" -e "SELECT id, name, version FROM software ORDER BY id; SELECT * FROM host_software ORDER BY host_id, software_id; SELECT host_id, software_id, installed_path FROM host_software_installed_paths; SELECT name FROM software_titles" > "$out/end-state.txt"
my -e "DROP DATABASE $db"
cat "$out/run.txt"
