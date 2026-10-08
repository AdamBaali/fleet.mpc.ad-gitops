#!/usr/bin/env bash
# Guide Step 4.1: import the step-ca certificates as trusted CAs.
# Imports the intermediate (the issuing CA) and the root.
. "$(dirname "$0")/lib.sh"
import() { # id file
  if exists "/certificates/ca/$1"; then echo "trusted CA $1 already present"; return; fi
  pf -X POST "$PF_API/certificates/ca/import" \
    -d "$(jq -n --arg id "$1" --rawfile pem "$2" '{id:$id, fileData:$pem}')" | jq -r '"imported \(.id): \(.subjectDN)"'
}
import steplabroot "$LAB/ping/certs/step-ca-root.crt"
import steplabintermediate "$LAB/ping/certs/step-ca-intermediate.crt"
