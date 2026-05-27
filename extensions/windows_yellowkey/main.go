//go:build windows

// Package main implements an osquery extension for the YellowKey BitLocker
// bypass (CVE-2026-45585). It registers one table, windows_yellowkey, that
// returns a single-row per-host verdict. The matching fix is
// mitigate-windows-yellowkey.ps1 in this repo, which applies Microsoft's
// autofstx strip from the CVE-2026-45585 MSRC advisory FAQ.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"log"
	"os/exec"
	"regexp"
	"strings"
	"time"

	"github.com/osquery/osquery-go"
	"github.com/osquery/osquery-go/plugin/table"
	"golang.org/x/sys/windows/registry"
)

const tableName = "windows_yellowkey"

// Verdicts emitted in the state column. First match in verdict() wins.
const (
	stateNotAffected    = "not_affected"
	stateMitigated      = "mitigated"
	stateMitigatedWinRE = "mitigated_winre_off"
	stateBitLockerOff   = "bitlocker_off"
	stateExposed        = "exposed"
)

// WinRE states returned by winreState().
const (
	winreEnabled  = "Enabled"
	winreDisabled = "Disabled"
	winreUnknown  = "unknown"
)

// BitLocker key protector type names from Get-BitLockerVolume.
const (
	kpTPM              = "Tpm"
	kpTPMPin           = "TpmPin"
	kpTPMPinStartupKey = "TpmPinStartupKey"
)

func main() {
	socket := flag.String("socket", "", "path to the osquery extension socket")
	timeout := flag.Int("timeout", 3, "seconds to wait for autoloaded extensions")
	interval := flag.Int("interval", 3, "seconds between connectivity checks")
	flag.Parse()

	if *socket == "" {
		log.Fatal("missing required --socket argument")
	}

	server, err := osquery.NewExtensionManagerServer(
		tableName, *socket,
		osquery.ServerTimeout(time.Duration(*timeout)*time.Second),
		osquery.ServerPingInterval(time.Duration(*interval)*time.Second),
	)
	if err != nil {
		log.Fatalf("create extension server: %v", err)
	}

	server.RegisterPlugin(table.NewPlugin(tableName, columns(), generate))

	if err := server.Run(); err != nil {
		log.Fatalf("run extension server: %v", err)
	}
}

func columns() []table.ColumnDefinition {
	return []table.ColumnDefinition{
		table.TextColumn("state"),
		table.TextColumn("state_reason"),
		table.IntegerColumn("needs_action"),
		table.TextColumn("winre_enabled"),
		table.IntegerColumn("tpm_only"),
		table.IntegerColumn("mitigated"),
	}
}

// generate returns one row: the host's YellowKey verdict and the signals
// behind it. Collection failures are logged and fall back to their safe
// defaults so the table always returns a row.
func generate(_ context.Context, _ table.QueryContext) ([]map[string]string, error) {
	affected := osAffected()
	winre := winreState()
	protected, tpmOnly := bitLockerState()
	mit := mitigated()

	state, reason := verdict(affected, winre, protected, mit)

	return []map[string]string{{
		"state":         state,
		"state_reason":  reason,
		"needs_action":  boolToInt(state == stateExposed),
		"winre_enabled": winre,
		"tpm_only":      boolToInt(tpmOnly),
		"mitigated":     boolToInt(mit),
	}}, nil
}

// verdict derives the per-host state. First match wins.
func verdict(affected bool, winre string, protected, mitigated bool) (state, reason string) {
	switch {
	case !affected:
		return stateNotAffected, "Windows 10 or unrecognised SKU; not vulnerable"
	case mitigated:
		return stateMitigated, "autofstx stripped from WinRE (BootExecMitigated marker set)"
	case winre == winreDisabled:
		return stateMitigatedWinRE, "WinRE disabled; the bypass cannot run"
	case !protected:
		return stateBitLockerOff, "BitLocker is not protecting any volume"
	default:
		return stateExposed, "WinRE on, BitLocker on, no mitigation applied"
	}
}

// osAffected reports whether this host runs an OS that YellowKey affects:
// Windows 11, Server 2022, or Server 2025. Windows 10 ships a different
// WinRE component and is safe.
func osAffected() bool {
	const key = `SOFTWARE\Microsoft\Windows NT\CurrentVersion`
	k, err := registry.OpenKey(registry.LOCAL_MACHINE, key, registry.QUERY_VALUE)
	if err != nil {
		log.Printf("open %s: %v", key, err)
		return false
	}
	defer k.Close()

	name, _, err := k.GetStringValue("ProductName")
	if err != nil {
		log.Printf("read ProductName: %v", err)
		return false
	}
	name = strings.ToLower(name)
	if strings.Contains(name, "windows 10") {
		return false
	}
	return strings.Contains(name, "windows 11") ||
		strings.Contains(name, "server 2022") ||
		strings.Contains(name, "server 2025")
}

// CJK-colon tolerant matches for "Windows RE status: Enabled/Disabled".
var (
	reEnabled  = regexp.MustCompile(`[:\x{FF1A}]\s*Enabled\b`)
	reDisabled = regexp.MustCompile(`[:\x{FF1A}]\s*Disabled\b`)
)

// winreState returns winreEnabled, winreDisabled, or winreUnknown by parsing
// reagentc /info. The status words are English-only; an unrecognised locale
// yields winreUnknown.
func winreState() string {
	out, err := exec.Command("reagentc.exe", "/info").CombinedOutput()
	if err != nil {
		// reagentc exits non-zero in some states but still prints useful
		// text, so parse what we captured rather than bailing.
		log.Printf("reagentc /info: %v", err)
	}
	switch text := string(out); {
	case reDisabled.MatchString(text):
		return winreDisabled
	case reEnabled.MatchString(text):
		return winreEnabled
	default:
		return winreUnknown
	}
}

// bitLockerState reports whether any volume is protected, and whether any
// volume uses TPM without a PIN (the configuration the published PoC
// targets). Both default to false when BitLocker data is unavailable.
func bitLockerState() (protected, tpmOnly bool) {
	const script = `
$ErrorActionPreference='SilentlyContinue'
$v = Get-BitLockerVolume
if (-not $v) { '[]'; exit }
$v | ForEach-Object {
  [pscustomobject]@{
    On  = [int]($_.ProtectionStatus -eq 'On')
    KPs = @($_.KeyProtector | ForEach-Object { $_.KeyProtectorType.ToString() })
  }
} | ConvertTo-Json -Compress -Depth 4`

	out, err := exec.Command("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script).Output()
	if err != nil {
		log.Printf("Get-BitLockerVolume: %v", err)
		return false, false
	}
	body := strings.TrimSpace(string(out))
	if body == "" || body == "[]" {
		return false, false
	}
	if !strings.HasPrefix(body, "[") {
		body = "[" + body + "]" // ConvertTo-Json emits a bare object for a single volume
	}

	var volumes []struct {
		On         int      `json:"On"`
		Protectors []string `json:"KPs"`
	}
	if err := json.Unmarshal([]byte(body), &volumes); err != nil {
		log.Printf("parse Get-BitLockerVolume output: %v", err)
		return false, false
	}
	for _, v := range volumes {
		if v.On == 1 {
			protected = true
		}
		if tpmWithoutPin(v.Protectors) {
			tpmOnly = true
		}
	}
	return protected, tpmOnly
}

// tpmWithoutPin reports whether a key protector set includes a TPM protector
// but no PIN.
func tpmWithoutPin(protectors []string) bool {
	tpm, pin := false, false
	for _, p := range protectors {
		switch p {
		case kpTPM:
			tpm = true
		case kpTPMPin, kpTPMPinStartupKey:
			pin = true
		}
	}
	return tpm && !pin
}

// mitigated reports whether mitigate-windows-yellowkey.ps1 has recorded a
// successful autofstx strip. A missing Fleet key is the normal
// pre-mitigation state, not an error.
func mitigated() bool {
	k, err := registry.OpenKey(registry.LOCAL_MACHINE, `SOFTWARE\Fleet\YellowKey`, registry.QUERY_VALUE)
	if err != nil {
		return false
	}
	defer k.Close()
	v, _, err := k.GetIntegerValue("BootExecMitigated")
	return err == nil && v == 1
}

// boolToInt renders a bool as the "1"/"0" string osquery integer columns use.
func boolToInt(b bool) string {
	if b {
		return "1"
	}
	return "0"
}
