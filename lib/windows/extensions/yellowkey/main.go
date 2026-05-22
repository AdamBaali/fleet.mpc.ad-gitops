//go:build windows

// Osquery extension that surfaces a Windows host's exposure to and
// mitigation state for the YellowKey BitLocker bypass (CVE-2026-45585).
//
// Microsoft's canonical mitigation script lives inside the CVE-2026-45585
// MSRC advisory FAQ ("Is there a script that I can copy and paste to
// implement a mitigation?"):
//
//   https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585
//
// That script strips autofstx.exe from the WinRE image's Session Manager
// BootExecute. This extension is the matching read side: it exposes the
// signals the report and dashboard need to identify exposed, mitigated,
// and unaffected hosts in real time. It does NOT mount the WinRE image
// or attempt to read the offline BootExecute value; the
// HKLM\SOFTWARE\Fleet\YellowKey\BootExecMitigated marker (written by
// mitigate-windows-yellowkey.ps1 in this same repo) is the proxy.
//
// Pattern adapted from allenhouchins/fleet-extensions/secureboot_cert_update.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/osquery/osquery-go"
	"github.com/osquery/osquery-go/plugin/table"
	"golang.org/x/sys/windows/registry"
)

const extensionSchemaVersion = "1.0.0"
const cveID = "CVE-2026-45585"

const (
	regFleetYellowKey = `SOFTWARE\Fleet\YellowKey`
	regWinNTCurrent   = `SOFTWARE\Microsoft\Windows NT\CurrentVersion`
)

var (
	socket   = flag.String("socket", "", "Path to the extensions UNIX domain socket")
	timeout  = flag.Int("timeout", 3, "Seconds to wait for autoloaded extensions")
	interval = flag.Int("interval", 3, "Seconds delay between connectivity checks")
)

// CJK-tolerant colon class so fullwidth-colon locales still match.
var (
	winreEnabledRe  = regexp.MustCompile(`[:\x{FF1A}]\s*Enabled\b`)
	winreDisabledRe = regexp.MustCompile(`[:\x{FF1A}]\s*Disabled\b`)
	winreLocationRe = regexp.MustCompile(`Windows RE location[:\x{FF1A}]\s*(\S.*)`)
)

func main() {
	flag.Parse()
	if *socket == "" {
		log.Fatalln("Missing required --socket argument")
	}

	server, err := osquery.NewExtensionManagerServer(
		"windows_yellowkey",
		*socket,
		osquery.ServerTimeout(time.Second*time.Duration(*timeout)),
		osquery.ServerPingInterval(time.Second*time.Duration(*interval)),
	)
	if err != nil {
		log.Fatalf("error creating extension: %s\n", err)
	}

	server.RegisterPlugin(table.NewPlugin(
		"windows_yellowkey",
		columns(),
		generate,
	))

	if err := server.Run(); err != nil {
		log.Fatal(err)
	}
}

func columns() []table.ColumnDefinition {
	return []table.ColumnDefinition{
		// Derived state.
		table.TextColumn("state"),
		table.TextColumn("state_reason"),
		table.IntegerColumn("needs_action"),
		table.TextColumn("action"),
		table.TextColumn("cve"),

		// OS.
		table.TextColumn("os_name"),
		table.TextColumn("os_build"),
		table.IntegerColumn("affected_os"),

		// WinRE.
		table.TextColumn("winre_enabled"),
		table.TextColumn("winre_location"),

		// BitLocker.
		table.IntegerColumn("bitlocker_volume_count"),
		table.IntegerColumn("bitlocker_protected_count"),
		table.IntegerColumn("bitlocker_max_protection_status"),
		table.TextColumn("bitlocker_key_protectors"),
		table.IntegerColumn("bitlocker_tpm_only_count"),

		// Fleet markers.
		table.IntegerColumn("allow_mitigation_marker"),
		table.IntegerColumn("bootexec_mitigated_marker"),

		// Lifecycle.
		table.TextColumn("collection_time"),
		table.TextColumn("extension_schema_version"),
	}
}

// collected holds raw values gathered from the device.
type collected struct {
	osName  string
	osBuild string
	osAffected bool

	winreState    string // "Enabled" | "Disabled" | "unknown"
	winreLocation string

	bitlockerVolumeCount      int
	bitlockerProtectedCount   int
	bitlockerMaxProtection    int
	bitlockerKeyProtectors    string
	bitlockerTpmOnlyCount     int
	bitlockerError            string

	allowMitigationMarker int // 0 or 1
	bootExecMitigatedMarker int // 0 or 1

	collectionTime time.Time
}

func generate(ctx context.Context, q table.QueryContext) ([]map[string]string, error) {
	c := &collected{collectionTime: time.Now().UTC()}

	collectOS(c)
	collectWinRE(c)
	collectBitLocker(c)
	collectFleetMarkers(c)

	state, reason, needsAction, action := deriveState(c)

	row := map[string]string{
		"state":         state,
		"state_reason":  reason,
		"needs_action":  boolToInt(needsAction),
		"action":        action,
		"cve":           cveID,

		"os_name":     c.osName,
		"os_build":    c.osBuild,
		"affected_os": boolToInt(c.osAffected),

		"winre_enabled":  c.winreState,
		"winre_location": c.winreLocation,

		"bitlocker_volume_count":          strconv.Itoa(c.bitlockerVolumeCount),
		"bitlocker_protected_count":       strconv.Itoa(c.bitlockerProtectedCount),
		"bitlocker_max_protection_status": strconv.Itoa(c.bitlockerMaxProtection),
		"bitlocker_key_protectors":        c.bitlockerKeyProtectors,
		"bitlocker_tpm_only_count":        strconv.Itoa(c.bitlockerTpmOnlyCount),

		"allow_mitigation_marker":   strconv.Itoa(c.allowMitigationMarker),
		"bootexec_mitigated_marker": strconv.Itoa(c.bootExecMitigatedMarker),

		"collection_time":          c.collectionTime.Format(time.RFC3339),
		"extension_schema_version": extensionSchemaVersion,
	}

	return []map[string]string{row}, nil
}

// --- Collectors ---------------------------------------------------------

func collectOS(c *collected) {
	k, err := registry.OpenKey(registry.LOCAL_MACHINE, regWinNTCurrent, registry.QUERY_VALUE)
	if err != nil {
		log.Printf("open %s: %v", regWinNTCurrent, err)
		return
	}
	defer k.Close()

	if v, _, err := k.GetStringValue("ProductName"); err == nil {
		c.osName = v
	}
	if v, _, err := k.GetStringValue("CurrentBuild"); err == nil {
		c.osBuild = v
	}

	// YellowKey affects Windows 11 and Windows Server 2022/2025. Windows 10
	// ships a different WinRE component and is not affected. ProductName
	// includes the SKU string for client (e.g., "Windows 11 Enterprise"). On
	// Server SKUs the ProductName begins with "Windows Server". Build numbers
	// help corroborate: Win11 >= 22000, Server 2022 >= 20348, Server 2025 >= 26100.
	name := strings.ToLower(c.osName)
	if strings.Contains(name, "windows 10") {
		c.osAffected = false
		return
	}
	if strings.Contains(name, "windows 11") {
		c.osAffected = true
		return
	}
	if strings.Contains(name, "windows server 2022") || strings.Contains(name, "windows server 2025") {
		c.osAffected = true
		return
	}
	// Fall back on build number for cases where ProductName is unusual.
	if b, err := strconv.Atoi(c.osBuild); err == nil {
		switch {
		case b >= 22000 && b < 99999:
			c.osAffected = true
		}
	}
}

func collectWinRE(c *collected) {
	cmd := exec.Command("reagentc.exe", "/info")
	out, err := cmd.CombinedOutput()
	if err != nil {
		// reagentc may exit non-zero on some failure modes but still print useful
		// text; fall through to parse what we have.
		log.Printf("reagentc /info: %v", err)
	}
	text := string(out)

	switch {
	case winreEnabledRe.MatchString(text):
		c.winreState = "Enabled"
	case winreDisabledRe.MatchString(text):
		c.winreState = "Disabled"
	default:
		c.winreState = "unknown"
	}

	if m := winreLocationRe.FindStringSubmatch(text); len(m) == 2 {
		c.winreLocation = strings.TrimSpace(m[1])
	}
}

// blVolume mirrors the JSON shape we emit from PowerShell.
type blVolume struct {
	MountPoint        string   `json:"MountPoint"`
	ProtectionStatus  int      `json:"ProtectionStatus"`
	KeyProtectorTypes []string `json:"KeyProtectorTypes"`
}

func collectBitLocker(c *collected) {
	// Get-BitLockerVolume returns key protector types that the osquery
	// bitlocker_info table does not expose. Emit just the fields we need as
	// compact JSON for parsing.
	psScript := `
$ErrorActionPreference = 'SilentlyContinue'
$vols = Get-BitLockerVolume
if (-not $vols) { '[]'; exit }
$out = $vols | ForEach-Object {
    [pscustomobject]@{
        MountPoint        = [string]$_.MountPoint
        ProtectionStatus  = [int]($_.ProtectionStatus -eq 'On')
        KeyProtectorTypes = @($_.KeyProtector | ForEach-Object { $_.KeyProtectorType.ToString() })
    }
}
$out | ConvertTo-Json -Compress -Depth 4
`
	cmd := exec.Command("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", psScript)
	out, err := cmd.Output()
	if err != nil {
		c.bitlockerError = err.Error()
		return
	}
	body := strings.TrimSpace(string(out))
	if body == "" || body == "[]" {
		return
	}
	// ConvertTo-Json emits an object (not an array) when there is a single volume.
	if !strings.HasPrefix(body, "[") {
		body = "[" + body + "]"
	}
	var vols []blVolume
	if err := json.Unmarshal([]byte(body), &vols); err != nil {
		c.bitlockerError = err.Error()
		return
	}

	c.bitlockerVolumeCount = len(vols)
	typesSet := map[string]struct{}{}
	for _, v := range vols {
		if v.ProtectionStatus > c.bitlockerMaxProtection {
			c.bitlockerMaxProtection = v.ProtectionStatus
		}
		if v.ProtectionStatus == 1 {
			c.bitlockerProtectedCount++
		}
		hasTpm := false
		hasPin := false
		for _, t := range v.KeyProtectorTypes {
			typesSet[t] = struct{}{}
			switch t {
			case "Tpm":
				hasTpm = true
			case "TpmPin", "TpmPinStartupKey":
				hasPin = true
			}
		}
		if hasTpm && !hasPin {
			c.bitlockerTpmOnlyCount++
		}
	}
	types := make([]string, 0, len(typesSet))
	for t := range typesSet {
		types = append(types, t)
	}
	// Sort for stable output across runs.
	stableSort(types)
	c.bitlockerKeyProtectors = strings.Join(types, ",")
}

// stableSort is a tiny insertion sort; the slice is small (<= ~8 distinct
// key protector types) so we avoid pulling in the sort package.
func stableSort(s []string) {
	for i := 1; i < len(s); i++ {
		j := i
		for j > 0 && s[j-1] > s[j] {
			s[j-1], s[j] = s[j], s[j-1]
			j--
		}
	}
}

func collectFleetMarkers(c *collected) {
	k, err := registry.OpenKey(registry.LOCAL_MACHINE, regFleetYellowKey, registry.QUERY_VALUE)
	if err != nil {
		// Missing key is fine; markers default to 0.
		return
	}
	defer k.Close()

	if v, _, err := k.GetIntegerValue("AllowMitigation"); err == nil && v == 1 {
		c.allowMitigationMarker = 1
	}
	if v, _, err := k.GetIntegerValue("BootExecMitigated"); err == nil && v == 1 {
		c.bootExecMitigatedMarker = 1
	}
}

// --- State machine ------------------------------------------------------

func deriveState(c *collected) (state, reason string, needsAction bool, action string) {
	if !c.osAffected {
		return "not_affected",
			fmt.Sprintf("%s is not in YellowKey's affected OS list", valueOr(c.osName, "this OS")),
			false, "none"
	}

	if c.bootExecMitigatedMarker == 1 {
		return "mitigated",
			"Fleet BootExecMitigated marker is set; mitigate-windows-yellowkey.ps1 stripped autofstx successfully",
			false, "verify_periodically"
	}

	if c.winreState == "Disabled" {
		return "mitigated_winre_off",
			"WinRE disabled; heavier mitigation in place (push-button reset and in-WinRE BitLocker recovery are unavailable)",
			false, "monitor"
	}

	if c.bitlockerProtectedCount == 0 {
		return "bitlocker_off",
			"BitLocker is not protecting any volume; YellowKey has no encrypted data to unlock",
			false, "none"
	}

	if c.winreState == "Enabled" {
		return "exposed",
			fmt.Sprintf("WinRE enabled, BitLocker protecting %d volume(s), no Fleet mitigation marker", c.bitlockerProtectedCount),
			true, "apply_mitigation"
	}

	// WinRE state is unknown (regex did not parse reagentc /info, likely a
	// locale we do not yet cover). Surface as exposed since the host meets
	// the OS + BitLocker criteria and we cannot confirm WinRE is off.
	return "exposed",
		fmt.Sprintf("WinRE state could not be parsed; BitLocker protecting %d volume(s); assume exposed and verify manually", c.bitlockerProtectedCount),
		true, "verify_winre_state"
}

// --- Helpers ------------------------------------------------------------

func boolToInt(b bool) string {
	if b {
		return "1"
	}
	return "0"
}

func valueOr(v, fallback string) string {
	if v == "" {
		return fallback
	}
	return v
}
