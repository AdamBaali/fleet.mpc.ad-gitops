#!/bin/bash
# Runs a query file from ../queries/ in the VM with osqueryi and prints JSON rows.
# Usage: vm-query.sh <vm> <file.sql>
# The SQL goes in on stdin: passed as an argument, PowerShell re-quotes it and osqueryi reads
# a leading "--" comment as a flag.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
vm=$1 sql=$2
cd "$here"
tools/qga-push.sh "$vm" "$sql" "C:\\ids\\q.sql" > /dev/null
tools/qga.sh "$vm" 'Get-Content -Raw C:\ids\q.sql | & "C:\Program Files\osquery\osqueryi.exe" --json' 120
