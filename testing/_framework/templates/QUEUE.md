# Overnight queue: <project>
# Run: testing/_framework/bin/overnight.py testing/<project>/QUEUE.md
# Each step needs a check: a command that exits 0 only when the step is done. Keep steps small.

## W-1: Boot win1 and wait for Windows
check: testing/_framework/vm/qga.sh win1 'hostname' 20
timeout: 20m

Start win1 from the base disk with testing/_framework/vm/qemu-boot.sh as a background task (FG=1), then wait for the
guest agent to answer. Don't click anything.

## W-2: Host facts
check: ls testing/<project>/test-evidence/win/S-0-*/01-*.txt
timeout: 10m

Record testing/_framework/hosts/host-facts.ps1 through qga.sh as test S-0 in testing/<project>/test-evidence/win.
