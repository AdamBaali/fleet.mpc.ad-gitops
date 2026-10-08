#!/usr/bin/env bash
# Phase 4 step 3: use the step-ca issued ping.lab certificate for the runtime server (9031/9032).
. "$(dirname "$0")/lib.sh"
ID=pinglab
if ! exists "/keyPairs/sslServer/$ID"; then
  P12="$(mktemp)"; PASS="$(openssl rand -hex 12)"
  cat "$LAB/ping/certs/step-ca-intermediate.crt" > "$P12.chain"
  openssl pkcs12 -export -name ping.lab -inkey "$LAB/ping/certs/ping.lab.key" -in "$LAB/ping/certs/ping.lab.crt" \
    -certfile "$P12.chain" -passout "pass:$PASS" -out "$P12"
  pf -X POST "$PF_API/keyPairs/sslServer/import" \
    -d "$(jq -n --arg id "$ID" --arg pw "$PASS" --arg d "$(base64 < "$P12" | tr -d '\n')" '{id:$id,fileData:$d,format:"PKCS12",password:$pw}')" \
    | jq -r '"imported \(.id): \(.subjectDN) valid to \(.validTo)"'
  rm -f "$P12" "$P12.chain"
else echo "key pair $ID already present"; fi
CUR="$(pf "$PF_API/keyPairs/sslServer/settings")"
NEW="$(jq --arg id "$ID" --arg base "$PF_API" '
  .runtimeServerCertRef = {id:$id, location:($base+"/keyPairs/sslServer/"+$id)}
  | .activeRuntimeServerCerts = [{id:$id, location:($base+"/keyPairs/sslServer/"+$id)}]' <<<"$CUR")"
pf -X PUT "$PF_API/keyPairs/sslServer/settings" -d "$NEW" | jq -c '{runtime:.runtimeServerCertRef.id, admin:.adminConsoleCertRef.id}'
