#!/bin/bash
# T-1 and T-2: run both report queries against faked IDs, then each negative control.
# Usage: scripts/run-t1-t2.sh <vm>   (from the project folder; the VM has osquery and C:\ids\fake-ids.ps1)
set -uo pipefail
vm=${1:-ids1}
cd "$(dirname "$0")/.."
export EV=$PWD/test-evidence/lab
. ../_framework/bin/ev.sh
fake() { echo "tools/qga.sh $vm '& powershell -NoProfile -ExecutionPolicy Bypass -File C:\\ids\\fake-ids.ps1 $1'"; }
q() { echo "scripts/vm-query.sh $vm queries/$1"; }

run_case() { # id title objective expected action
  ev_init "$1" "$2" "$3" "$4" > /dev/null
  ev_cmd "$1" fake-$5 "$(fake "$5")"
  ev_cmd "$1" intune "$(q intune-device-id.sql)"
  ev_cmd "$1" entra "$(q entra-device-id.sql)"
}

ev_init T-0 "Baseline and osquery version" "Record the VM before any fake" "No JoinInfo subkeys, no MS-Organization-Access certificates" > /dev/null
ev_cmd T-0 os "tools/qga.sh $vm '(Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture | Format-List | Out-String).Trim(); & \"C:\\Program Files\\osquery\\osqueryi.exe\" --version'"
ev_cmd T-0 fake-clear "$(fake clear)"

run_case T-1 "Query logic on faked data" "Both queries return the faked IDs" "Intune row equals expected intune_device_id; Entra row equals expected entra_device_id" setup
ev_cmd T-1 certs "$(q checks/personal-certs.sql)"
run_case T-2a "No fakes" "Queries return nothing on a host that is not joined or enrolled" "No rows from either query" clear
run_case T-2b "JoinInfo without its certificate" "A subkey whose certificate is gone is ignored" "Intune row only; no Entra row" nocert
run_case T-2c "Certificate from another issuer" "A matching subkey and certificate from a non-Entra issuer is ignored" "No Entra row" otherca
run_case T-2d "Stale second enrollment" "An older Intune enrollment key is visible, not hidden" "Two Intune rows, each with its key; one Entra row" stale
run_case T-2e "Two Entra joins" "The newest join certificate wins" "One Entra row with the newer certificate's ID" twojoins
ev_cmd T-2e fake-clear "$(fake clear)"
