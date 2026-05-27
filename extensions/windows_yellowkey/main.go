//go:build windows

// Osquery extension for the YellowKey BitLocker bypass (CVE-2026-45585).
//
// Exposes one table, windows_yellowkey, with a per-host verdict. The
// matching fix is mitigate-windows-yellowkey.ps1 in this repo, which
// applies Microsoft's autofstx strip from the CVE-2026-45585 MSRC FAQ.
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

var (
	socket   = flag.String("socket", "", "Path to the osquery extension socket")
	timeout  = flag.Int("timeout", 3, "Seconds to wait for autoloaded extensions")
	interval = flag.Int("interval", 3, "Seconds between connectivity checks")
)

func main() {
	flag.Parse()
	if *socket == "" {
		log.Fatalln("missing required --socket argument")
	}
	server, err := osquery.NewExtensionManagerServer(
		"windows_yellowkey", *socket,
		osquery.ServerTimeout(time.Second*time.Duration(*timeout)),
		osquery.ServerPingInterval(time.Second*time.Duration(*interval)),
	)
	if err != nil {
		log.Fatalf("create extension: %s", err)
	}
	server.RegisterPlugin(table.NewPlugin("windows_yellowkey", columns(), generate))
	if err := server.Run(); err != nil {
		log.Fatal(err)
	}
}

func columns() []table.ColumnDefinition {
	return []table.ColumnDefinition{
		table.TextColumn("state"),           // the verdict
		table.TextColumn("state_reason"),    // one-line explanation
		table.IntegerColumn("needs_action"), // 1 when state is exposed
		table.TextColumn("winre_enabled"),   // Enabled | Disabled | unknown
		table.IntegerColumn("tpm_only"),     // 1 when a volume uses TPM without a PIN
		table.IntegerColumn("mitigated"),    // 1 when the BootExecMitigated marker is set
	}
}

func generate(_ context.Context, _ table.QueryContext) ([]map[string]string, error) {
	winre := winreState()
	protected, tpmOnly := bitLocker()
	mitigated := mitigatedMarker()
	state, reason := verdict(osAffected(), winre, protected, mitigated)

	return []map[string]string{{
		"state":         state,
		"state_reason":  reason,
		"needs_action":  boolToInt(state == "exposed"),
		"winre_enabled": winre,
		"tpm_only":      boolToInt(tpmOnly),
		"mitigated":     boolToInt(mitigated),
	}}, nil
}

// verdict derives the per-host state. First match wins.
func verdict(affected bool, winre string, protected, mitigated bool) (state, reason string) {
	switch {
	case !affected:
		return "not_affected", "Windows 10 or unrecognised SKU; not vulnerable"
	case mitigated:
		return "mitigated", "autofstx stripped from WinRE (BootExecMitigated marker set)"
	case winre == "Disabled":
		return "mitigated_winre_off", "WinRE disabled; the bypass cannot run"
	case !protected:
		return "bitlocker_off", "BitLocker is not protecting any volume"
	default:
		return "exposed", "WinRE on, BitLocker on, no mitigation applied"
	}
}

// osAffected reports whether this host is Windows 11, Server 2022, or
// Server 2025. Windows 10 ships a different WinRE component and is safe.
func osAffected() bool {
	k, err := registry.OpenKey(registry.LOCAL_MACHINE,
		`SOFTWARE\Microsoft\Windows NT\CurrentVersion`, registry.QUERY_VALUE)
	if err != nil {
		return false
	}
	defer k.Close()
	name, _, _ := k.GetStringValue("ProductName")
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

// winreState returns "Enabled", "Disabled", or "unknown" (locale not parsed).
func winreState() string {
	out, _ := exec.Command("reagentc.exe", "/info").CombinedOutput()
	text := string(out)
	switch {
	case reDisabled.MatchString(text):
		return "Disabled"
	case reEnabled.MatchString(text):
		return "Enabled"
	default:
		return "unknown"
	}
}

// bitLocker reports whether any volume is protected, and whether any protected
// volume uses TPM without a PIN (the configuration the published PoC targets).
func bitLocker() (protected, tpmOnly bool) {
	const ps = `
$ErrorActionPreference='SilentlyContinue'
$v = Get-BitLockerVolume
if (-not $v) { '[]'; exit }
$v | ForEach-Object {
  [pscustomobject]@{
    On  = [int]($_.ProtectionStatus -eq 'On')
    KPs = @($_.KeyProtector | ForEach-Object { $_.KeyProtectorType.ToString() })
  }
} | ConvertTo-Json -Compress -Depth 4`
	out, err := exec.Command("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", ps).Output()
	if err != nil {
		return false, false
	}
	body := strings.TrimSpace(string(out))
	if body == "" || body == "[]" {
		return false, false
	}
	if !strings.HasPrefix(body, "[") {
		body = "[" + body + "]" // ConvertTo-Json emits a bare object for a single volume
	}
	var vols []struct {
		On  int      `json:"On"`
		KPs []string `json:"KPs"`
	}
	if json.Unmarshal([]byte(body), &vols) != nil {
		return false, false
	}
	for _, vol := range vols {
		if vol.On == 1 {
			protected = true
		}
		hasTpm, hasPin := false, false
		for _, kp := range vol.KPs {
			switch kp {
			case "Tpm":
				hasTpm = true
			case "TpmPin", "TpmPinStartupKey":
				hasPin = true
			}
		}
		if hasTpm && !hasPin {
			tpmOnly = true
		}
	}
	return protected, tpmOnly
}

// mitigatedMarker reads the success marker that mitigate-windows-yellowkey.ps1
// writes after a verified autofstx strip.
func mitigatedMarker() bool {
	k, err := registry.OpenKey(registry.LOCAL_MACHINE, `SOFTWARE\Fleet\YellowKey`, registry.QUERY_VALUE)
	if err != nil {
		return false
	}
	defer k.Close()
	v, _, err := k.GetIntegerValue("BootExecMitigated")
	return err == nil && v == 1
}

func boolToInt(b bool) string {
	if b {
		return "1"
	}
	return "0"
}
