#!/usr/bin/env bash
# Guide Step 4.2-4.3: X.509 Certificate IdP Adapter instance. The guide does not mention
# Client Auth Port and Client Auth Hostname, but the adapter needs both.
. "$(dirname "$0")/lib.sh"
ID=x509lab
BODY="$(jq -n --arg id "$ID" '{
  id: $id, name: "Fleet X.509",
  pluginDescriptorRef: {id: "com.pingidentity.adapters.idp.clientcert.ClientCertIdpAuthnAdapter"},
  configuration: {
    fields: [
      {name: "Client Auth Port", value: "9032"},
      {name: "Client Auth Hostname", value: "ping.lab"},
      {name: "Parse Client Cert Subject and Issuer DNs", value: "true"}
    ],
    tables: [{name: "Constrain Acceptable Root Issuers", rows: []}]},
  attributeContract: {
    coreAttributes: [
      {name: "SubjectDN", masked: false, pseudonym: true}, {name: "IssuerDN", masked: false},
      {name: "SerialNumber", masked: false}, {name: "email", masked: false},
      {name: "ClientCertificateChain", masked: false}],
    extendedAttributes: [{name: "CN", masked: false}],
    uniqueUserKeyAttribute: "SubjectDN"}
}')"
if exists "/idp/adapters/$ID"; then pf -X PUT "$PF_API/idp/adapters/$ID" -d "$BODY" | jq -c '{updated:.id}'
else pf -X POST "$PF_API/idp/adapters" -d "$BODY" | jq -c '{created:.id, ext:.attributeContract.extendedAttributes}'; fi
