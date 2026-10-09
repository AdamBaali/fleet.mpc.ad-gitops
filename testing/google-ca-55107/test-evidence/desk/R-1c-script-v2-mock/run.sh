#!/bin/bash
# R-1c: run the current sync script against the mock (fake curl on PATH, made-up lab.test data). Writes 01..06 next to this file.
# usage: bash run.sh <path to sync-fleet-hosts-to-google.sh>
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; SCRIPT="${1:?usage: run.sh <script>}"
cp "$SCRIPT" "$HERE/script-under-test.sh"
export MOCK="$HERE/mock" PATH="$HERE/mock/bin:$PATH" FLEET_URL=https://fleet.mock FLEET_API_TOKEN=x GOOGLE_ACCESS_TOKEN=x GOOGLE_CUSTOMER_ID=C0mock
run() { # name, then env assignments; runs the script, saves output, exit code and the Google writes
  local name=$1; shift
  : > "$MOCK/calls.log"
  local shown=() a; for a in "$@"; do case "$a" in GOOGLE_CREDENTIALS=*) shown+=("GOOGLE_CREDENTIALS=<throwaway test key>");; *) shown+=("$a");; esac; done
  { echo "# $name: ${shown[*]:-defaults}"; env "$@" bash "$HERE/script-under-test.sh" 2>&1; echo "[exit $?]"
    echo "# Google token requests:"; grep -c 'oauth2.googleapis.com/token' "$MOCK/calls.log"
    echo "# Google writes:"; grep '^PATCH' "$MOCK/calls.log" | sed -E 's#https://cloudidentity.googleapis.com/v1/##; s#\?customer=[^ ]*##' || echo "(none)"
  } | sed "s#$HERE/##g" > "$HERE/$name.txt"
}
{ echo "# shellcheck"; shellcheck "$HERE/script-under-test.sh" && echo "clean"; echo "# bash -n"; bash -n "$HERE/script-under-test.sh" && echo "clean"; } > "$HERE/01-lint.txt" 2>&1
run 02-defaults
run 03-byod-allowed 'ENROLLMENT_STATUSES=On (automatic),On (manual),On (personal)' DRY_RUN=true
run 04-custom-emails-allowed EMAIL_SOURCES=mdm_idp_accounts,custom DRY_RUN=true
run 05-guard-no-iphones MOCK_HOSTS="$MOCK/fleet-hosts-no-iphones.json"
run 06-guard-no-idp-emails MOCK_HOSTS="$MOCK/fleet-hosts-no-idp-emails.json"
# Token from the service account key: a throwaway key made for this run (never saved next to the evidence).
KEYDIR=$(mktemp -d); openssl genrsa -out "$KEYDIR/k.pem" 2048 2>/dev/null
FAKE_KEY=$(jq -n --rawfile k "$KEYDIR/k.pem" '{client_email: "sync@mock-project.iam.gserviceaccount.com", private_key: $k}'); rm -r "$KEYDIR"
run 07-token-from-key GOOGLE_ACCESS_TOKEN= GOOGLE_CREDENTIALS="$FAKE_KEY" GOOGLE_ADMIN_EMAIL=admin@lab.test DRY_RUN=true
run 08-token-refused GOOGLE_ACCESS_TOKEN= GOOGLE_CREDENTIALS="$FAKE_KEY" GOOGLE_ADMIN_EMAIL=admin@lab.test MOCK_TOKEN_ERROR=1
rm -f "$MOCK/calls.log"
grep -h -E "^# 0|\\[exit" "$HERE"/0*.txt
