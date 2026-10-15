#!/usr/bin/env bash
# Run PowerShell in a Windows UTM VM through the guest agent (runs as SYSTEM) and print its output.
# usage: tools/win-run.sh <vm> 'powershell code'      or      tools/win-run.sh <vm> - < script.ps1
# Output is written in the guest to C:\Windows\Temp\vmrun-<id>.out (UTF-8) and pulled back. Waits up to ${WAIT:-90}s.
U=/Applications/UTM.app/Contents/MacOS/utmctl; VM="$1"; CODE="$2"; [ "$CODE" = - ] && CODE="$(cat)"
ID="$(date +%s)$RANDOM"; G="C:\\Windows\\Temp\\vmrun-$ID"; T="$(mktemp)"
cat > "$T" <<EOF
\$ErrorActionPreference = 'Continue'
\$o = & {
$CODE
} 2>&1 | Out-String -Width 250
[IO.File]::WriteAllText('$G.out', \$o + "[exit \$LASTEXITCODE]")
EOF
out=$($U file push "$VM" "$G.ps1" < "$T" 2>&1); rm -f "$T"
[ -n "$out" ] && { echo "push failed: $out" >&2; exit 1; }
out=$($U exec "$VM" --cmd powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$G.ps1" 2>&1)
echo "$out" | grep -q -i error && { echo "exec failed: $out" >&2; exit 1; }
end=$(( $(date +%s) + ${WAIT:-90} ))
while [ "$(date +%s)" -lt "$end" ]; do
  r=$($U file pull "$VM" "$G.out" 2>/dev/null)
  if echo "$r" | grep -q '\[exit '; then printf '%s\n' "$r" | tr -d '\r'; exit 0; fi
  sleep 2
done
echo "timed out after ${WAIT:-90}s waiting for $G.out" >&2; exit 1
