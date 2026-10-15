#!/usr/bin/env bash
# Start a program on the signed-in user's desktop in the Windows VM (the guest agent runs as SYSTEM and can't show UI).
# Uses a one-off scheduled task with an Interactive logon principal (no password needed while the user is signed in).
# usage: tools/win-gui.sh <vm> <user> '<program>' ['<arguments>']
# e.g.   tools/win-gui.sh bitlocker-lab lab control.exe '/name Microsoft.BitLockerDriveEncryption'
H="$(cd "$(dirname "$0")" && pwd)"; VM="$1"; USER_NAME="$2"; PROG="$3"; ARGS="${4:-}"
WAIT=60 "$H/win-run.sh" "$VM" "
\$a = New-ScheduledTaskAction -Execute '$PROG' $( [ -n "$ARGS" ] && printf -- "-Argument '%s'" "$ARGS" )
\$p = New-ScheduledTaskPrincipal -UserId '$USER_NAME' -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'lab-gui' -Action \$a -Principal \$p -Force | Out-Null
Start-ScheduledTask -TaskName 'lab-gui'; Start-Sleep 3
(Get-ScheduledTask -TaskName 'lab-gui' | Get-ScheduledTaskInfo).LastTaskResult
Unregister-ScheduledTask -TaskName 'lab-gui' -Confirm:\$false
"
