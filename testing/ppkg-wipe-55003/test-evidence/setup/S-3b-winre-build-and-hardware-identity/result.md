# S-3b: WinRE, build, and hardware identity

**Objective:** Recovery environment on, Windows build, and that the SMBIOS UUID equals the UTM VM UUID  
**Expected:** WinRE Enabled; UUID matches config.plist  
**Run:** 2026-10-26T17:25:03Z to 2026-10-26T17:29:12Z

## Evidence

- `01-utm-vm-uuid.txt`: `/usr/libexec/PlistBuddy -c 'Print :Information:UUID' $HOME/Library/Containers/com.utmapp.UTM/Data/Documents/pp`
- `02-reagentc.png` (window screenshot: UTM / ppkg-golden-oobe)
- `03-identity.png` (window screenshot: UTM / ppkg-golden-oobe)
- `04-identity-2.png` (window screenshot: UTM / ppkg-golden-oobe)

## What happened

UUID B2731972-B7D4-44E8-A27C-E360E8D7C9FE equals the UTM VM UUID, so vm/clone.sh new|same controls the hardware UUID
Fleet sees. Serial (IdentifyingNumber) is empty under QEMU, so Fleet matches on UUID only. The guest keyboard was UK
layout (fixed in the answer file for later builds); tools/vm-input.sh ps sends PowerShell base64-encoded to avoid it.

## Result: PASS

WinRE Enabled (10.0.26100.9444), Windows 11 Pro 10.0.26300, SMBIOS UUID equals the UTM VM UUID, empty serial.
