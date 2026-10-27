# S-4: Builder VM with Configuration Designer

**Objective:** A Windows VM that builds provisioning packages and never enrolls in Fleet  
**Expected:** ICD.exe (Windows Configuration Designer's command line) installed from Microsoft's ADK  
**Run:** 2026-10-26T17:46:54Z to 2026-10-26T17:49:43Z

## Evidence

- `01-adk-install.txt`: `tools/vm-exec.sh ppkg-builder 'New-Item -ItemType Directory -Force C:\build | Out-Null; Invoke-WebRequest -Use`

## What happened

Builder = a clone of the golden VM (new UUID), left at the region screen. No user account, no fleetd. Commands run as
SYSTEM through the guest agent. Uses the ADK's Imaging and Configuration Designer instead of the Microsoft Store app:
same engine (ICD.exe), no Store sign-in needed. Lab difference from the guide, which uses the Store app's GUI.

## Result: PASS

ADK 10.1.26100.9457 installed in the builder VM with ICD.exe (Configuration Designer command line). The builder has no
user account and no fleetd.
