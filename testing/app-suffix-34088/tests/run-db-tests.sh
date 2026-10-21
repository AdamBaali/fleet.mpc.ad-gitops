#!/usr/bin/env bash
# Runs app_suffix_test.go inside a Fleet checkout, against Fleet's test MySQL on localhost:3307.
# Usage: tests/run-db-tests.sh <path-to-fleet-checkout>
# Output: test-evidence/db/<fleet tag or main-sha>/
# Needs Docker and Go. Uses one compose project for every checkout, because Fleet's test helper
# loads the schema with `docker compose exec mysql_test` in the checkout's project.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
fleet="$(cd "${1:?path to a fleet checkout}" && pwd)"
ref="$(git -C "$fleet" describe --tags --exact-match 2>/dev/null || echo "main-$(git -C "$fleet" rev-parse --short HEAD)")"
out="$here/test-evidence/db/$ref"

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-fleet-app-suffix}"
(cd "$fleet" && docker compose up -d mysql_test >/dev/null)
# A checkout with a different compose file recreates the container. Wait for a real login:
# mysqladmin ping answers before the root password is set.
c="$(cd "$fleet" && docker compose ps -q mysql_test)"
for _ in $(seq 1 60); do docker exec "$c" mysql -uroot -ptoor -e "SELECT 1" >/dev/null 2>&1 && break; sleep 2; done
cp "$here/tests/app_suffix_test.go" "$fleet/server/datastore/mysql/zz_app_suffix_test.go"
trap 'rm -f "$fleet/server/datastore/mysql/zz_app_suffix_test.go"' EXIT

rm -rf "$out" && mkdir -p "$out"
{
  echo "# fleet: $ref $(git -C "$fleet" log -1 --format='%h %cd' --date=short)"
  cd "$fleet" && MYSQL_TEST=1 APP_SUFFIX_DIR="$here" APP_SUFFIX_OUT="$out" \
    go test ./server/datastore/mysql/ -run '^TestAppSuffix$' -count=1 -v 2>&1 | grep -v '^go: downloading'
} | tee "$out/go-test.txt"
# Keep evidence portable: no local paths.
sed -i.bak -e "s#$fleet#<fleet>#g" -e "s#$here#.#g" "$out"/*.txt && rm -f "$out"/*.bak
