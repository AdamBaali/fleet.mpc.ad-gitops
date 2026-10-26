#!/bin/bash
# Creates the mock IdP's signing key and two test users in ../private/idp/ (git ignores it). Run once.
# Re-running replaces the key, and then the metadata in default.yml must be updated too.
set -euo pipefail
cd "$(dirname "$0")"
P=../private/idp; mkdir -p "$P"; umask 077
openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj "/CN=ppkg-wipe-lab-idp" \
  -keyout "$P/server.pem" -out "$P/server.crt" 2>/dev/null
# The container's web server user must read the key.
chmod 644 "$P/server.pem" "$P/server.crt"
p1=$(openssl rand -hex 6); p2=$(openssl rand -hex 6)
cat > "$P/users.php" <<PHP
<?php
\$config = array(
    'example-userpass' => array(
        'exampleauth:UserPass',
        'eua-user-1:$p1' => array('email' => 'eua-user-1@example.com', 'displayname' => array('EUA User 1')),
        'eua-user-2:$p2' => array('email' => 'eua-user-2@example.com', 'displayname' => array('EUA User 2')),
    ),
);
PHP
chmod 644 "$P/users.php"
printf 'eua-user-1 %s\neua-user-2 %s\n' "$p1" "$p2" > "$P/CREDENTIALS.txt"
echo "Wrote $P (key, cert, users). Credentials in $P/CREDENTIALS.txt"
