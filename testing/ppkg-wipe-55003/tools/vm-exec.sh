#!/bin/bash
# Runs PowerShell in a UTM VM through the QEMU guest agent (installed with UTM's guest tools) and prints its output and
# exit code as text, so results go into evidence files instead of screenshots. Runs as SYSTEM.
#   tools/vm-exec.sh <vm> '<powershell script>' [timeout seconds, default 600]
set -euo pipefail
VM="$1"; SCRIPT="$2"; T="${3:-600}"
B64=$(printf "%s" "\$ProgressPreference = 'SilentlyContinue'; $SCRIPT" | iconv -f UTF-8 -t UTF-16LE | base64 | tr -d '\n')
osascript - "$VM" "$B64" "$T" <<'APPLESCRIPT'
on run argv
	set vmName to item 1 of argv
	set b64 to item 2 of argv
	set limit to (item 3 of argv) as integer
	tell application "UTM"
		set vm to virtual machine named vmName
		set p to execute vm at "powershell.exe" with arguments {"-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", b64} with output capturing
		set waited to 0
		repeat
			set r to get result p
			if exited of r then exit repeat
			if waited ≥ limit then return "TIMEOUT after " & limit & " s"
			delay 2
			set waited to waited + 2
		end repeat
		set out to ""
		try
			set out to output text of r
		end try
		set err to ""
		try
			set err to error text of r
		end try
		return out & err & "[exit " & (exit code of r) & "]"
	end tell
end run
APPLESCRIPT
