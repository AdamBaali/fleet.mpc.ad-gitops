#!/bin/bash
# T-3 control: with wrong expected IDs, compare-t3.py must report FAIL. Restores the real file after.
vm=${1:-ids1}
tools/qga.sh "$vm" 'Copy-Item C:\ids\expected.json C:\ids\expected.real.json; $e = Get-Content -Raw C:\ids\expected.json | ConvertFrom-Json; $e.intune_device_id = "00000000-0000-0000-0000-000000000000"; $e.entra_device_id = "00000000-0000-0000-0000-000000000000"; $e | ConvertTo-Json | Set-Content C:\ids\expected.json; "expected IDs replaced with zeros"'
python3 scripts/compare-t3.py "$vm" 35 2793 2794; rc=$?
tools/qga.sh "$vm" 'Move-Item -Force C:\ids\expected.real.json C:\ids\expected.json; "restored"'
echo "compare exit $rc (1 expected)"
