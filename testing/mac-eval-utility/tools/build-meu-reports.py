#!/usr/bin/env python3
"""Build Fleet reports that mirror Apple's Mac Evaluation Utility (MEU) tests.

Usage:
  build-meu-reports.py "/Applications/Mac Evaluation Utility.app" [--repo ROOT]

Reads the test catalog the MEU app ships (Contents/Resources/assessmentsMetadata-v-*.json
and en.lproj/*.strings) and writes:
  lib/macos/reports/mac-evaluation-utility.reports.yml   the Fleet reports
  testing/mac-eval-utility/COVERAGE.md                    every MEU test and how it is covered

Apple's catalog is not committed. Only facts taken from it (test IDs, titles, payload keys,
host names) land in the generated files, so a new MEU release is a re-run of this script.

Every report returns the same columns, so results from all reports can be combined:
  meu_id    MEU assessment ID, to match a row in an MEU CSV or JSON export
  category  MEU category or subcategory title
  test      MEU test title
  result    PASS, WARN, FAIL, or INFO (from MEU's own severity for that outcome)
  value     what the host returned
"""

import argparse
import glob
import json
import os
import plistlib
import re
import sys

# MEU severity to report result. MEU weights Critical and Major as failures, Minor as a warning.
SEVERITY = {
    "success": "PASS",
    "critical": "FAIL",
    "major": "FAIL",
    "minor": "WARN",
    "informational": "INFO",
    "unknown": "INFO",
}

# Ports osquery can't test: curl_certificate speaks TLS over TCP and curl speaks HTTP.
# NTP is UDP and the School Manager upload host is SFTP.
UNTESTABLE_PORTS = {123: "NTP over UDP; osquery has no UDP probe", 22: "SFTP; osquery has no SSH probe"}

# curl_certificate's timeout bounds reads only. connect() isn't bounded, so a firewall that drops
# packets can hold each host for the OS connect timeout. See TEST_PLAN.md T-9.
TLS_TIMEOUT = 3

REPORT_DEFAULTS = {
    "automations_enabled": "false",
    "discard_data": "false",
    "interval": "86400",
    "logging": "snapshot",
    "observer_can_run": "true",
    "platform": "darwin",
}


def q(s):
    """SQL string literal."""
    return "'" + str(s).replace("'", "''") + "'"


def load_catalog(app):
    res = os.path.join(app, "Contents", "Resources")
    versions = sorted(glob.glob(os.path.join(res, "assessmentsMetadata-v-*.json")))
    if not versions:
        sys.exit(f"no assessmentsMetadata-v-*.json under {res}")
    data = json.load(open(versions[-1]))
    version = next(iter(data))
    strings = {}
    for f in glob.glob(os.path.join(res, "en.lproj", "*.strings")):
        raw = open(f, "rb").read()
        try:
            strings.update(plistlib.loads(raw))
            continue
        except Exception:
            pass
        enc = "utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8"
        text = raw.decode(enc, errors="replace")
        for k, v in re.findall(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', text):
            strings[k] = v
    info = plistlib.load(open(os.path.join(app, "Contents", "Info.plist"), "rb"))
    return data[version], strings, info.get("CFBundleShortVersionString", "?")


def walk(node, path=()):
    """Yield (category path, assessment) for every test in the catalog, in MEU order."""
    for key in ("categories", "subcategories"):
        children = node.get(key) or {}
        for child in sorted(children.values(), key=lambda c: c.get("order", 0)):
            yield from walk(child, path + (child,))
    for a in sorted((node.get("assessments") or {}).values(), key=lambda a: a.get("runOrder", 0)):
        yield path, a


def params(a):
    return {p["name"]: p["value"] for p in a.get("parameters", [])}


def sev(a, state):
    """Report result for an MEU outcome value such as 'Firewall.enabled' or 'unmanaged'."""
    for s in a.get("scores", []):
        v = s.get("value")
        if v == state or (isinstance(v, str) and v.split(".")[-1] == state):
            return SEVERITY.get(s["severity"].lower(), "INFO")
    return "INFO"


def head(a, title, category):
    return f"SELECT {q(a['assessmentID'])} AS meu_id, {q(category)} AS category, {q(title)} AS test,"


# ---------------------------------------------------------------------------------------------
# Tests MEU runs against a profile payload key. The catalog names the payload type and key, so
# these are generated. managed_policies holds payloads that land in managed preferences.
# MEU states: enabled (key true or set), disabled (key false), unmanaged (absent), multiple.
# ---------------------------------------------------------------------------------------------
def managed_check(a, title, category):
    p = params(a)
    domains = [d.strip() for d in p["managementPayloadType"].split(",")]
    key = p["managementKey"]
    # A domain ending in .user is a per-user payload, so user rows count too.
    user_scoped = any(d.endswith(".user") for d in domains)
    where = f"domain IN ({', '.join(q(d) for d in domains)}) AND name = {q(key)}"
    if not user_scoped:
        where += " AND username = ''"
    return f"""{head(a, title, category)}
  CASE
    WHEN mp.n = 0 THEN {q(sev(a, 'unmanaged'))}
    WHEN mp.n > 1 THEN {q(sev(a, 'multiple'))}
    WHEN mp.v IN ('0', 'false') THEN {q(sev(a, 'disabled'))}
    ELSE {q(sev(a, 'enabled'))}
  END AS result,
  CASE
    WHEN mp.n = 0 THEN 'unmanaged'
    WHEN mp.n > 1 THEN 'multiple values: ' || mp.vals
    ELSE 'managed: {key} = ' || mp.v
  END AS value
FROM (SELECT COUNT(DISTINCT value) AS n, MAX(value) AS v, GROUP_CONCAT(DISTINCT value) AS vals
      FROM managed_policies WHERE {where}) mp"""


# ---------------------------------------------------------------------------------------------
# Hand-written checks, keyed by MEU assessment ID. Each body follows head() and returns
# result and value. The note says how close it is to what MEU does.
# ---------------------------------------------------------------------------------------------
MANUAL = {
    "CI_assess-Computer_Name": ("system_info.computer_name", """
  'INFO' AS result, computer_name AS value
FROM system_info"""),
    "CI_assess-MacOS_Version_Number": ("os_version", """
  'INFO' AS result, version || ' (' || build || ')' AS value
FROM os_version"""),
    "CI_assess-Mac_Model": ("system_info.hardware_model", """
  'INFO' AS result, hardware_model AS value
FROM system_info"""),
    "CI_assess-CoProcessor_Version": ("os_version.arch, ibridge_info", """
  CASE
    WHEN o.arch = 'arm64' THEN 'PASS'
    WHEN i.v LIKE '%T2%' THEN 'PASS'
    ELSE 'WARN'
  END AS result,
  CASE
    WHEN o.arch = 'arm64' THEN 'Apple silicon'
    WHEN i.v IS NULL THEN 'no Secure Enclave found'
    ELSE i.v
  END AS value
FROM os_version o, (SELECT MAX(coprocessor_version) AS v FROM ibridge_info) i"""),
    "NI_assess-Public_DNS_Name": ("system_info.hostname (MEU runs /bin/hostname)", """
  'INFO' AS result, hostname AS value
FROM system_info"""),
    "NI_assess-Primary_Network_Name": ("dns_resolvers, first search domain", """
  'INFO' AS result,
  COALESCE((SELECT address FROM dns_resolvers WHERE type = 'search' ORDER BY id LIMIT 1), 'none') AS value"""),
    "NI_assess-Search_Domains": ("dns_resolvers search list. MEU also lists supplemental match domains, which osquery doesn't expose", """
  'INFO' AS result,
  COALESCE((SELECT GROUP_CONCAT(address, ', ') FROM dns_resolvers WHERE type = 'search'), 'none') AS value"""),
    "NI_assess-DNS_Servers": ("dns_resolvers nameservers", """
  'INFO' AS result,
  COALESCE((SELECT GROUP_CONCAT(address, ', ') FROM dns_resolvers WHERE type = 'nameserver'), 'none') AS value"""),
    # MEU flags addresses in 100.64.0.0/10 (carrier-grade NAT), which overlaps some VPNs and Apple services.
    "NI_assess-Private_IP_Address": ("interface_addresses on the default route interface", """
  CASE WHEN ip.n = 0 THEN 'FAIL' WHEN ip.cgnat > 0 THEN 'WARN' ELSE 'PASS' END AS result,
  CASE WHEN ip.n = 0 THEN 'no IPv4 address on the default route' ELSE ip.addrs END AS value
FROM (
  SELECT COUNT(*) AS n, GROUP_CONCAT(interface || ' ' || address, ', ') AS addrs,
         SUM(address GLOB '100.6[4-9].*' OR address GLOB '100.[7-9][0-9].*'
             OR address GLOB '100.1[01][0-9].*' OR address GLOB '100.12[0-7].*') AS cgnat
  FROM interface_addresses
  WHERE interface IN (SELECT interface FROM routes WHERE destination = '0.0.0.0' AND netmask = 0)
    AND address LIKE '%.%' AND address NOT LIKE '169.254.%'
) ip"""),
    "NI_assess-Network_Service_Order": ("interface_addresses: interfaces with an IPv4 address. MEU lists them in service order, which osquery doesn't expose", """
  'INFO' AS result,
  COALESCE((SELECT GROUP_CONCAT(DISTINCT interface) FROM interface_addresses
            WHERE address LIKE '%.%' AND interface != 'lo0' AND address NOT LIKE '169.254.%'), 'none') AS value"""),
    # MEU compares the file's SHA-256 with the macOS default. The hash comes from the catalog.
    "NI_assess-Host_File_Status": ("hash of /private/etc/hosts against MEU's default hash, plus the non-default etc_hosts entries", """
  CASE WHEN h.sha256 IS NULL THEN 'FAIL' WHEN h.sha256 = {hostsFileHash} THEN 'PASS' ELSE 'FAIL' END AS result,
  CASE
    WHEN h.sha256 IS NULL THEN 'hosts file not found'
    WHEN h.sha256 = {hostsFileHash} THEN 'unmodified'
    ELSE 'modified: ' || COALESCE((SELECT GROUP_CONCAT(address || ' ' || hostnames, '; ') FROM etc_hosts
                                  WHERE hostnames NOT IN ('localhost', 'broadcasthost')), 'comments or spacing only')
  END AS value
FROM (SELECT (SELECT sha256 FROM hash WHERE path = '/private/etc/hosts') AS sha256) h"""),
    "NI_assess-Proxy_Information": ("plist: proxy types turned on in SystemConfiguration preferences. MEU asks CFNetwork for the proxy used for https://www.apple.com", """
  'INFO' AS result,
  COALESCE((SELECT GROUP_CONCAT(DISTINCT REPLACE(SUBSTR(subkey, INSTR(subkey, '/Proxies/') + 9), 'Enable', ''))
            FROM plist
            WHERE path = '/Library/Preferences/SystemConfiguration/preferences.plist'
              AND key = 'NetworkServices' AND subkey LIKE '%/Proxies/%Enable' AND value = '1'), 'No proxy') AS value"""),
    "NI_assess-WiFi_Details": ("wifi_status. The network name needs Location Services for osquery on recent macOS", """
  'INFO' AS result,
  COALESCE((SELECT COALESCE(NULLIF(network_name, ''), 'name hidden') || ', ' || security_type
                   || ', channel ' || channel || ', RSSI ' || rssi
            FROM wifi_status LIMIT 1), 'not connected to Wi-Fi') AS value"""),
    "MM_assess-PPPCConfig": ("plist: entries in the TCC MDM overrides file that PPPC profiles write", """
  'INFO' AS result,
  CASE WHEN p.n = 0 THEN 'No Privacy Preferences Policy Control settings were found'
       ELSE p.n || ' apps or services with PPPC settings' END AS value
FROM (SELECT COUNT(DISTINCT key) AS n FROM plist
      WHERE path = '/Library/Application Support/com.apple.TCC/MDMOverrides.plist') p"""),
    "MM_assess-Organization_Name": ("plist: the Automated Device Enrollment cloud configuration record (ADE hosts only)", """
  CASE WHEN o.v IS NULL THEN 'FAIL' ELSE 'PASS' END AS result,
  COALESCE(o.v, 'No organization name found') AS value
FROM (SELECT (SELECT value FROM plist
              WHERE path = '/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound'
                AND subkey LIKE '%OrganizationName' LIMIT 1) AS v) o"""),
    "MM_assess-MDM_Server_URL": ("mdm.server_url", """
  CASE WHEN COALESCE(m.url, '') = '' THEN 'FAIL' ELSE 'PASS' END AS result,
  COALESCE(NULLIF(m.url, ''), 'No device management service URL found') AS value
FROM (SELECT (SELECT server_url FROM mdm) AS url) m"""),
    # Any HTTP status means the server answered. MEU only checks that it is reachable.
    "MM_assess-MDM_External_Reachability": ("curl GET of mdm.server_url; any HTTP status counts as reachable", """
  CASE WHEN COALESCE(m.url, '') = '' THEN 'FAIL' WHEN COALESCE(c.code, 0) > 0 THEN 'PASS' ELSE 'FAIL' END AS result,
  CASE
    WHEN COALESCE(m.url, '') = '' THEN 'Not enrolled in device management service'
    WHEN COALESCE(c.code, 0) > 0 THEN 'reachable, HTTP ' || c.code
    ELSE 'unreachable'
  END AS value
FROM (SELECT (SELECT server_url FROM mdm) AS url) m
LEFT JOIN (SELECT url, CAST(response_code AS INTEGER) AS code FROM curl
           WHERE url = (SELECT server_url FROM mdm)) c ON c.url = m.url"""),
    "MM_assess-Automated_Device_Enrollment": ("mdm.installed_from_dep", """
  CASE WHEN m.dep = 'true' THEN 'PASS' WHEN m.dep IS NULL THEN 'INFO' ELSE 'FAIL' END AS result,
  CASE WHEN m.dep = 'true' THEN 'Enrolled via Automated Device Enrollment'
       WHEN m.dep IS NULL THEN 'Unknown' ELSE 'Not enrolled via Automated Device Enrollment' END AS value
FROM (SELECT (SELECT installed_from_dep FROM mdm) AS dep) m"""),
    "MM_assess-MDM_Enrollment_Type": ("mdm.enrolled and mdm.user_approved", """
  CASE WHEN m.enrolled = 'true' THEN 'PASS' WHEN m.enrolled IS NULL THEN 'INFO' ELSE 'FAIL' END AS result,
  CASE WHEN m.enrolled = 'true' AND m.approved = 'true' THEN 'Yes (User Approved)'
       WHEN m.enrolled = 'true' THEN 'Yes'
       WHEN m.enrolled IS NULL THEN 'Unknown' ELSE 'No' END AS value
FROM (SELECT (SELECT enrolled FROM mdm) AS enrolled, (SELECT user_approved FROM mdm) AS approved) m"""),
    "MM_assess-System_Preferences_Configuration": ("managed_policies: any com.apple.systempreferences key", """
  'INFO' AS result,
  CASE WHEN s.n = 0 THEN 'System Settings are unmanaged' ELSE 'managed: ' || s.keys END AS value
FROM (SELECT COUNT(*) AS n, GROUP_CONCAT(name, ', ') AS keys FROM managed_policies
      WHERE domain = 'com.apple.systempreferences') s"""),
    "MM_assess-NetworkTimeConfiguration": ("file_lines: server lines in /private/etc/ntp.conf", """
  CASE WHEN t.n = 0 OR t.n > 1 THEN 'FAIL' WHEN t.s = 'time.apple.com' THEN 'PASS' ELSE 'WARN' END AS result,
  CASE WHEN t.n = 0 THEN 'The network time server couldn''t be determined' ELSE t.servers END AS value
FROM (SELECT COUNT(*) AS n,
             MAX(TRIM(SUBSTR(TRIM(line), 8))) AS s,
             GROUP_CONCAT(TRIM(SUBSTR(TRIM(line), 8)), ', ') AS servers
      FROM file_lines WHERE path = '/private/etc/ntp.conf' AND TRIM(line) LIKE 'server %') t"""),
    "MM_assess-Secure_Boot": ("secureboot (Apple silicon description, Intel T2 secure_mode)", """
  CASE WHEN b.description = 'Full Security' OR b.secure_mode = 1 THEN 'PASS' ELSE 'FAIL' END AS result,
  COALESCE(NULLIF(b.description, ''), 'secure_mode ' || b.secure_mode, 'Unknown secure boot status') AS value
FROM (SELECT (SELECT description FROM secureboot) AS description,
             (SELECT secure_mode FROM secureboot) AS secure_mode) b"""),
    # dscl's AuthenticationAuthority carries ;SecureToken; for each user that holds one.
    "MM_assess-Secure_Token": ("dscl AuthenticationAuthority for each local login user", """
  CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
  CASE WHEN t.n = 0 THEN 'All users have a secure token' ELSE 'Users without secure tokens: ' || t.users END AS value
FROM (SELECT COUNT(*) AS n, GROUP_CONCAT(u.username, ', ') AS users
      FROM users u
      CROSS JOIN dscl d ON d.command = 'read' AND d.path = '/Users/' || u.username AND d.key = 'AuthenticationAuthority'
      WHERE u.uid >= 500 AND u.shell NOT LIKE '%/false' AND u.username NOT LIKE '\\_%' ESCAPE '\\'
        AND d.value NOT LIKE '%;SecureToken;%') t"""),
    # Fleet's own escrow writes /var/db/FileVaultPRK.dat, so either source counts.
    "MM_assess-File_Vault_Recovery_Key_Escrow_Configuration": ("managed_policies FDERecoveryKeyEscrow Location, or the escrow file /var/db/FileVaultPRK.dat", """
  CASE WHEN e.loc IS NOT NULL OR e.prk > 0 THEN 'PASS' ELSE 'FAIL' END AS result,
  CASE WHEN e.loc IS NOT NULL THEN 'FileVault key escrow configuration found: ' || e.loc
       WHEN e.prk > 0 THEN 'FileVault key escrow file found'
       ELSE 'FileVault key escrow is unmanaged' END AS value
FROM (SELECT (SELECT value FROM managed_policies WHERE domain = 'com.apple.security.FDERecoveryKeyEscrow'
              AND name = 'Location' LIMIT 1) AS loc,
             (SELECT COUNT(*) FROM file WHERE path = '/var/db/FileVaultPRK.dat') AS prk) e"""),
    "MM_assess-FileVault_Status": ("filevault_status", """
  CASE WHEN f.s = 'on' THEN 'PASS' WHEN f.s IS NULL THEN 'INFO' ELSE 'WARN' END AS result,
  CASE WHEN f.s = 'on' THEN 'FileVault is enabled' WHEN f.s IS NULL THEN 'FileVault status is unknown'
       ELSE 'FileVault is ' || f.s END AS value
FROM (SELECT (SELECT status FROM filevault_status) AS s) f"""),
    "MM_assess-Gatekeeper_Status": ("gatekeeper.assessments_enabled", """
  CASE WHEN g.e = 1 THEN 'PASS' WHEN g.e IS NULL THEN 'INFO' ELSE 'WARN' END AS result,
  CASE WHEN g.e = 1 THEN 'Gatekeeper is enabled' WHEN g.e IS NULL THEN 'Gatekeeper status is unknown'
       ELSE 'Gatekeeper is disabled' END AS value
FROM (SELECT (SELECT assessments_enabled FROM gatekeeper) AS e) g"""),
    "MM_assess-SIP_Status": ("sip_config flag sip", """
  CASE WHEN s.e = 1 THEN 'PASS' WHEN s.e IS NULL THEN 'INFO' ELSE 'FAIL' END AS result,
  CASE WHEN s.e = 1 THEN 'System Integrity Protection is enabled' WHEN s.e IS NULL THEN 'System Integrity Protection status is unknown'
       ELSE 'System Integrity Protection is disabled' END AS value
FROM (SELECT (SELECT enabled FROM sip_config WHERE config_flag = 'sip') AS e) s"""),
    # Same source as MEU: dscl . -read /Users/root Password. A single * means disabled.
    "MM_assess-Root_User_Status": ("dscl read /Users/root Password, the command MEU runs", """
  CASE WHEN r.v = '*' THEN 'PASS' WHEN r.v LIKE '%**%' THEN 'FAIL' ELSE 'INFO' END AS result,
  CASE WHEN r.v = '*' THEN 'The root user is disabled' WHEN r.v LIKE '%**%' THEN 'The root user is enabled'
       ELSE 'Unknown: ' || COALESCE(r.v, 'no value') END AS value
FROM (SELECT (SELECT value FROM dscl WHERE command = 'read' AND path = '/Users/root' AND key = 'Password') AS v) r"""),
    "MM_assess-AuthDB_Mods": ("authdb system.login.screensaver; the macOS default rule is use-login-window-ui", """
  'INFO' AS result,
  CASE WHEN a.r LIKE '%use-login-window-ui%' THEN 'The authorization database has not been modified'
       ELSE 'system.login.screensaver rule: ' || COALESCE(a.r, 'unknown') END AS value
FROM (SELECT (SELECT json_extract(json_result, '$.rule') FROM authdb
              WHERE right_name = 'system.login.screensaver') AS r) a"""),
    # The console owner is the logged-in user. Group 80 is admin.
    "MM_assess-User-Type": ("owner of /dev/console and membership of group 80 (admin)", """
  'INFO' AS result,
  CASE WHEN c.uid IS NULL OR c.uid = 0 THEN 'No user logged in'
       WHEN EXISTS (SELECT 1 FROM user_groups WHERE uid = c.uid AND gid = 80) THEN 'admin'
       ELSE 'standard' END AS value
FROM (SELECT (SELECT uid FROM file WHERE path = '/dev/console') AS uid) c"""),
    "IDM_AD_assess-AD_Computer_Info": ("ad_config", """
  'INFO' AS result,
  COALESCE((SELECT 'Bound to ' || MAX(domain) FROM ad_config HAVING COUNT(*) > 0), 'Not bound to Active Directory') AS value"""),
    "IDM_SC_assess-Attribute_Mapping_Type": ("file: /private/etc/SmartcardLogin.plist", """
  'INFO' AS result,
  CASE WHEN EXISTS (SELECT 1 FROM file WHERE path = '/private/etc/SmartcardLogin.plist')
       THEN 'Smart card attribute mapping found' ELSE 'Smart card attribute mapping not found' END AS value"""),
    "KI_assess-KEXTs": ("kernel_extensions not named com.apple.*", """
  CASE WHEN k.n = 0 THEN 'PASS' ELSE 'WARN' END AS result,
  CASE WHEN k.n = 0 THEN 'No third-party kernel extensions found' ELSE k.names END AS value
FROM (SELECT COUNT(*) AS n, GROUP_CONCAT(name || ' ' || version, ', ') AS names FROM kernel_extensions
      WHERE name NOT LIKE 'com.apple.%' AND name != '__kernel__') k"""),
    "SEI_assess-System_Extension_List": ("system_extensions", """
  'INFO' AS result,
  COALESCE((SELECT GROUP_CONCAT(identifier || ' (' || state || ')', ', ') FROM system_extensions), 'none') AS value"""),
    # MEU reads Background Task Management (sfltool dumpbtm). On macOS, startup_items reads the same store.
    "AI_assess-Agents": ("startup_items type agent outside /System", """
  'INFO' AS result,
  COALESCE((SELECT COUNT(*) || ': ' || GROUP_CONCAT(DISTINCT name) FROM startup_items
            WHERE type = 'agent' AND path NOT LIKE '/System/%' HAVING COUNT(*) > 0), 'none') AS value"""),
    "AI_assess-Daemons": ("startup_items type daemon outside /System", """
  'INFO' AS result,
  COALESCE((SELECT COUNT(*) || ': ' || GROUP_CONCAT(DISTINCT name) FROM startup_items
            WHERE type = 'daemon' AND path NOT LIKE '/System/%' HAVING COUNT(*) > 0), 'none') AS value"""),
    "AI_assess-LoginItems": ("startup_items that aren't agents or daemons", """
  'INFO' AS result,
  COALESCE((SELECT COUNT(*) || ': ' || GROUP_CONCAT(DISTINCT name) FROM startup_items
            WHERE type NOT IN ('agent', 'daemon') HAVING COUNT(*) > 0), 'none') AS value"""),
    # signature returns one row per architecture slice. hash_* = 0 skips hashing to keep it cheap.
    "AI_assess-Unsigned_Apps": ("signature of each app in /Applications", """
  CASE WHEN u.n = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
  CASE WHEN u.n = 0 THEN 'No unsigned applications found' ELSE u.apps END AS value
FROM (SELECT COUNT(*) AS n, GROUP_CONCAT(path, ', ') AS apps FROM (
        SELECT a.path FROM apps a
        CROSS JOIN signature s ON s.path = a.path AND s.hash_resources = 0 AND s.hash_executable = 0
        WHERE a.path LIKE '/Applications/%'
        GROUP BY a.path HAVING MAX(s.signed) = 0)) u"""),
    # Only a problem on Apple silicon, where an Intel-only app needs Rosetta.
    "AI_assess-Intel_Only_Apps": ("signature architecture slices of each app in /Applications", """
  CASE WHEN i.n = 0 THEN 'PASS' WHEN (SELECT arch FROM os_version) = 'arm64' THEN 'FAIL' ELSE 'INFO' END AS result,
  CASE WHEN i.n = 0 THEN 'No non-universal applications found' ELSE i.apps END AS value
FROM (SELECT COUNT(*) AS n, GROUP_CONCAT(path, ', ') AS apps FROM (
        SELECT a.path FROM apps a
        CROSS JOIN signature s ON s.path = a.path AND s.hash_resources = 0 AND s.hash_executable = 0
        WHERE a.path LIKE '/Applications/%'
        GROUP BY a.path
        HAVING SUM(s.arch IN ('arm64', 'arm64e')) = 0 AND SUM(s.arch = 'x86_64') > 0)) i"""),
}

# Tests with no osquery equivalent, and why. Listed in COVERAGE.md, not in the reports.
NOT_COVERED = {
    "CI_assess-Biometrics": "Touch ID enrollment comes from bioutil; no osquery table exposes it",
    "NI_assess-Network_Quality": "networkQuality runs a load test; not suitable for osquery",
    "NI_assess-Public_IP_Address": "Fleet already records each host's public IP",
    "CH_assess-Custom_Hosts": "Add hosts with --extra-host when building the reports",
    "CC_assess-Content_Caching_Server_Info": "AssetCacheLocatorUtil has no osquery equivalent",
    "MM_assess-MDM_UserChannel_Enabled": "Managed user channel state isn't exposed to osquery",
    "MM_assess-Proxy_Configuration": "Proxy payloads don't land in managed preferences; NI_assess-Proxy_Information reports the proxies in use",
    "MM_assess-Bootstrap_Token": "Bootstrap token status comes from profiles status; no osquery table",
    "MM_assess-ICloud-Recovery-Key": "No osquery table exposes iCloud FileVault recovery",
    "MM_assess-Volume_Owner": "Volume ownership comes from diskutil apfs listUsers; no osquery table",
    "IDM_AD_assess-Kerberos_SSO_Extension_Realms": "Extensible SSO payloads don't land in managed preferences; app_sso_platform needs the extension ID and realm up front",
    "IDM_AD_assess-IsPSSOConfigured": "As above. A fleet that knows its Platform SSO extension can query app_sso_platform directly",
    "IDM_AD_assess-SSO_Extensions_Configured": "As above",
    "IDM_AD_assess-AD_DNS_Info": "Needs SRV lookups; osquery has no DNS query table",
    "IDM_AD_assess-AD_User_Info": "Mobile account detection isn't exposed to osquery",
    "IDM_SC_assess-Account_Pairing": "sc_auth identities has no osquery equivalent",
    "AI_assess-Non_Notarized_Apps": "osquery's signature table doesn't report notarization",
    "AI_assess-SHA1_Apps": "Candidate: codesign.cdhash_sha256 is empty for SHA-1-only signatures. Needs testing on a host first",
    "AI_assess-ConferencingApps": "Inspects app binaries for ScreenCaptureKit symbols; no osquery equivalent",
    "KI_assess-MDM_KEXTs": "Kernel extension policy payloads don't land in managed preferences",
    "ANR_assess-APNS_Reachability": "Reads apsd's connection state; the courier host checks cover reachability",
}
BONJOUR_NOTE = "Bonjour browsing (dns-sd) has no osquery equivalent"


def network_rows(catalog, strings, extra_hosts):
    """One row per unique host and port, in MEU order, with the first group that lists it."""
    rows, seen = [], set()
    anr = catalog["categories"]["Apple_Network_Reachability"]
    for path, a in walk({"subcategories": anr["subcategories"]}):
        p = params(a)
        if "host" not in p:
            continue
        host, _, port = p["host"].rpartition(":")
        port = int(port)
        group = strings.get(path[-1].get("keyForName", ""), path[-1].get("categoryID"))
        title = p.get("formattedTitle") or f"{host} (port {port})"
        rows.append(dict(id=a["assessmentID"], group=group, host=host, port=port, title=title,
                         method=a["assessmentMethod"], dup=(host, port) in seen))
        seen.add((host, port))
    for h in extra_hosts:
        host, _, port = h.rpartition(":")
        rows.append(dict(id="CH_assess-Custom_Hosts", group="Custom Hosts", host=host, port=int(port),
                         title=f"{host} (port {port})", method="assessHost", dup=False))
    return rows


def network_sql(tls_rows, http_rows=(), interception_host=None):
    """One query: a TLS handshake per TLS host, an HTTP GET per port 80 host, and the interception check."""
    ctes, selects = [], []
    if tls_rows:
        targets = ",\n    ".join(
            f"({q(r['id'])}, {q(r['group'])}, {q(r['title'])}, {q(r['host'] + ':' + str(r['port']))})"
            for r in tls_rows)
        hostnames = sorted({r["host"] + ":" + str(r["port"]) for r in tls_rows})
        if interception_host and interception_host not in hostnames:
            hostnames.append(interception_host)
        ctes.append(f"""tls_targets AS (
  SELECT column1 AS meu_id, column2 AS category, column3 AS test, column4 AS hostname FROM (VALUES
    {targets}
  )
)""")
        ctes.append(f"""certs AS (
  SELECT hostname, tls_version, issuer_organization FROM curl_certificate
  WHERE timeout = {TLS_TIMEOUT} AND hostname IN ({", ".join(q(h) for h in hostnames)})
)""")
        selects.append("""SELECT t.meu_id, t.category, t.test,
  CASE
    WHEN c.hostname IS NULL THEN 'FAIL'
    WHEN c.tls_version NOT IN ('TLSv1.2', 'TLSv1.3') THEN 'WARN'
    ELSE 'PASS'
  END AS result,
  CASE
    WHEN c.hostname IS NULL THEN t.hostname || ': no TLS connection'
    ELSE t.hostname || ': ' || c.tls_version || ', issuer ' || COALESCE(c.issuer_organization, 'unknown')
  END AS value
FROM tls_targets t LEFT JOIN certs c ON c.hostname = t.hostname""")
    if interception_host:
        # MEU checks that this host's chain ends at an Apple root. A TLS inspection proxy re-signs it.
        selects.append(f"""SELECT 'ANR_assess-HTTPS_Interception', 'Push Notifications (Port 443)', 'HTTPS interception',
  CASE WHEN c.issuer_organization = 'Apple Inc.' THEN 'PASS' ELSE 'FAIL' END,
  CASE WHEN c.hostname IS NULL THEN {q(interception_host)} || ': no TLS connection'
       ELSE {q(interception_host)} || ': issuer ' || COALESCE(c.issuer_organization, 'unknown') END
FROM (SELECT 1) one LEFT JOIN certs c ON c.hostname = {q(interception_host)}""")
    if http_rows:
        targets = ",\n    ".join(
            f"({q(r['id'])}, {q(r['group'])}, {q(r['title'])}, {q('http://' + r['host'] + '/')})" for r in http_rows)
        urls = ", ".join(sorted({q("http://" + r["host"] + "/") for r in http_rows}))
        ctes.append(f"""http_targets AS (
  SELECT column1 AS meu_id, column2 AS category, column3 AS test, column4 AS url FROM (VALUES
    {targets}
  )
)""")
        ctes.append(f"""responses AS (
  SELECT url, CAST(response_code AS INTEGER) AS code FROM curl WHERE url IN ({urls})
)""")
        selects.append("""SELECT t.meu_id, t.category, t.test,
  CASE WHEN COALESCE(r.code, 0) > 0 THEN 'PASS' ELSE 'FAIL' END AS result,
  CASE WHEN COALESCE(r.code, 0) > 0 THEN t.url || ': HTTP ' || r.code ELSE t.url || ': no response' END AS value
FROM http_targets t LEFT JOIN responses r ON r.url = t.url""")
    return "WITH " + ",\n".join(ctes) + "\n" + "\nUNION ALL\n".join(selects)


def yaml_block(text, indent=4):
    pad = " " * indent
    return "\n".join(pad + line if line else "" for line in text.splitlines())


def report_yaml(name, description, query, interval=None):
    out = [f"- name: {name}"]
    out.append(f"  automations_enabled: {REPORT_DEFAULTS['automations_enabled']}")
    out.append("  description: |")
    out.append(yaml_block(description))
    out.append(f"  discard_data: {REPORT_DEFAULTS['discard_data']}")
    out.append(f"  interval: {interval or REPORT_DEFAULTS['interval']}")
    out.append(f"  logging: {REPORT_DEFAULTS['logging']}")
    out.append(f"  observer_can_run: {REPORT_DEFAULTS['observer_can_run']}")
    out.append(f"  platform: {REPORT_DEFAULTS['platform']}")
    out.append("  query: |")
    out.append(yaml_block(query.strip() + ";"))
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("app", help="path to Mac Evaluation Utility.app")
    ap.add_argument("--repo", default=os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    ap.add_argument("--extra-host", action="append", default=[], metavar="HOST:PORT",
                    help="add a TLS host to the network report (MEU's Custom Hosts)")
    args = ap.parse_args()

    catalog, strings, app_version = load_catalog(args.app)
    tests = list(walk(catalog))

    def title_of(a):
        return strings.get(a.get("keyForName", ""), a["assessmentID"])

    def category_of(path):
        return strings.get(path[-1].get("keyForName", ""), path[-1].get("categoryID"))

    # Group local checks into reports by top-level MEU category.
    buckets = {"info": [], "mgmt": [], "apps": []}
    bucket_of = {"Computer_Information": "info", "Network_Information": "info",
                 "Mac_Management": "mgmt", "Identity_Management": "mgmt", "Application_Information": "apps"}
    coverage = []  # (category, id, title, status, how)
    for path, a in tests:
        top = path[0]["categoryID"]
        aid, title, cat = a["assessmentID"], title_of(a), category_of(path)
        if top == "Apple_Network_Reachability":
            continue
        p = params(a)
        if aid in MANUAL:
            how, body = MANUAL[aid]
            body = body.replace("{hostsFileHash}", q(p.get("hostsFileHash", "")))
            buckets[bucket_of[top]].append(head(a, title, cat) + body)
            coverage.append((cat, aid, title, "Covered", how))
        elif "managementKey" in p and "managementPayloadType" in p:
            buckets[bucket_of[top]].append(managed_check(a, title, cat))
            coverage.append((cat, aid, title, "Covered",
                             f"managed_policies {p['managementPayloadType']} / {p['managementKey']}"))
        else:
            why = NOT_COVERED.get(aid) or (BONJOUR_NOTE if aid.startswith("BN_") else None)
            if why is None:
                sys.exit(f"new MEU test with no mapping: {aid} ({title}). Add it to MANUAL or NOT_COVERED.")
            coverage.append((cat, aid, title, "Not covered", why))

    # Network: TLS ports through curl_certificate, port 80 through curl, the rest listed as not covered.
    net = network_rows(catalog, strings, args.extra_host)
    tls_hosts = [r for r in net if r["port"] not in UNTESTABLE_PORTS and r["port"] != 80 and not r["dup"]
                 and r["method"] != "assessHttpsInterception"]
    courier = [r for r in tls_hosts if "courier" in r["host"]]
    services = [r for r in tls_hosts if "courier" not in r["host"]]
    http = [r for r in net if r["port"] == 80 and not r["dup"]]
    interception = next((r for r in net if r["method"] == "assessHttpsInterception"), None)
    for r in net:
        status, how = "Covered", ""
        if r["port"] in UNTESTABLE_PORTS:
            status, how = "Not covered", UNTESTABLE_PORTS[r["port"]]
        elif r["method"] == "assessHttpsInterception":
            how = "curl_certificate issuer must be Apple Inc."
        elif r["port"] == 80:
            how = "curl HTTP GET"
        else:
            how = "curl_certificate TLS handshake"
        if r["dup"]:
            how = (how + "; " if how else "") + "same host and port tested once"
        coverage.append((r["group"], r["id"], f"{r['host']}:{r['port']}", status, how))
    covered_ids = {c[1] for c in coverage}
    for path, a in tests:
        if a["assessmentID"] not in covered_ids:
            why = NOT_COVERED.get(a["assessmentID"])
            if why is None:
                sys.exit(f"new MEU network test with no mapping: {a['assessmentID']}")
            coverage.append((category_of(path), a["assessmentID"], title_of(a), "Not covered", why))

    columns = ("Every report returns meu_id, category, test, result (PASS, WARN, FAIL, INFO),\n"
               "and value. meu_id matches the test in an MEU export. See testing/mac-eval-utility/.")
    reports = [
        report_yaml(
            "MEU - Computer and network information (macOS)",
            f"Mac Evaluation Utility {app_version} computer and network information tests.\n{columns}",
            "\nUNION ALL\n".join(buckets["info"])),
        report_yaml(
            "MEU - Mac management and identity (macOS)",
            f"Mac Evaluation Utility {app_version} Mac management, Apple Intelligence, software update,\n"
            f"and identity tests. Managed settings come from managed_policies, the payloads MEU reads.\n{columns}",
            "\nUNION ALL\n".join(buckets["mgmt"])),
        report_yaml(
            "MEU - Application information (macOS)",
            f"Mac Evaluation Utility {app_version} application tests: unsigned and Intel-only apps in\n"
            f"/Applications, kernel and system extensions, background items. Reads every app's\n"
            f"signature, so it runs once a day.\n{columns}",
            "\nUNION ALL\n".join(buckets["apps"])),
        report_yaml(
            "MEU - Apple network services (macOS)",
            f"Mac Evaluation Utility {app_version} Apple network services tests: a TLS handshake to each\n"
            f"Apple host MEU tests ({len(services)} hosts), and an HTTP request to each port 80 host\n"
            f"({len(http)}). FAIL means no connection. WARN means TLS older than 1.2.\n"
            f"Connects directly, without the system proxy.\n{columns}",
            network_sql(services, http)),
        report_yaml(
            "MEU - Push notification hosts (macOS)",
            f"Mac Evaluation Utility {app_version} push notification tests: a TLS handshake to each\n"
            f"APNs courier host on ports 443 and 5223 ({len(courier)} checks), and MEU's HTTPS\n"
            f"interception check, which fails when {interception['host'] if interception else 'the courier host'} isn't signed by Apple.\n{columns}",
            network_sql(courier, (), interception and f"{interception['host']}:{interception['port']}")),
    ]

    header = (
        f"# Fleet reports that mirror Apple's Mac Evaluation Utility (MEU) {app_version} tests.\n"
        "# Generated by testing/mac-eval-utility/tools/build-meu-reports.py from the test catalog\n"
        "# inside the MEU app. Don't edit by hand: change the generator and re-run it.\n"
        "# testing/mac-eval-utility/COVERAGE.md lists every MEU test and how each one is covered.\n\n")
    out = os.path.join(args.repo, "lib", "macos", "reports", "mac-evaluation-utility.reports.yml")
    with open(out, "w") as f:
        f.write(header + "\n\n".join(reports) + "\n")

    n_cov = sum(1 for c in coverage if c[3] == "Covered")
    lines = [
        "# MEU test coverage",
        "",
        f"Generated from Mac Evaluation Utility {app_version} by `tools/build-meu-reports.py`. Don't edit by hand.",
        "",
        f"MEU {app_version} runs {len(coverage)} tests. The Fleet reports cover {n_cov}. "
        f"The other {len(coverage) - n_cov} need data osquery can't read; the table says why.",
        "",
        "| Category | MEU test ID | Test | Status | How |",
        "| --- | --- | --- | --- | --- |",
    ]
    for cat, aid, title, status, how in coverage:
        lines.append(f"| {cat} | `{aid}` | {title} | {status} | {how.replace('|', '/')} |")
    with open(os.path.join(args.repo, "testing", "mac-eval-utility", "COVERAGE.md"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {out}\nMEU {app_version}: {len(coverage)} tests, {n_cov} covered")


if __name__ == "__main__":
    main()
