#!/usr/bin/env python3
"""Logic check for the MEU reports, without a Mac.

Builds a SQLite table for every osquery table the reports use (columns from Fleet's osquery
schema), loads a fixture host, runs each report, and compares results with what the fixture
should produce. Two fixtures: a compliant Mac and a non-compliant one (the negative control).

This checks SQL syntax and CASE logic only. osquery's virtual tables behave differently from
plain tables (required columns, IN handling, network timeouts), so a real Mac still has to run
the reports. See TEST_PLAN.md.

Usage:
  sqlite-logic-check.py [--schema osquery_fleet_schema.json] [--reports FILE]
"""

import argparse
import json
import os
import re
import sqlite3
import sys

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
DEFAULT_SCHEMA = os.path.expanduser("~/.cache/fleet-gitops-skill/osquery_fleet_schema.json")
DEFAULT_HOSTS_SHA = "c7dd0e2ed261ce76d76f852596c5b54026b9a894fa481381ffd399b556c0e2da"


def common(good):
    """Fixture rows shared by both hosts. good=True is compliant."""
    yes, no = ("1", "0") if good else ("0", "1")
    return {
        "system_info": [dict(computer_name="Lab Mac", hostname="lab-mac.local", hardware_model="Mac15,3")],
        "os_version": [dict(version="26.1", build="25B78", arch="arm64" if good else "x86_64")],
        "ibridge_info": [] if good else [dict(coprocessor_version="Apple T1 chip")],
        "dns_resolvers": [dict(id=0, type="search", address="corp.example"),
                          dict(id=1, type="nameserver", address="10.0.0.1")],
        "routes": [dict(destination="0.0.0.0", netmask=0, interface="en0")],
        "interface_addresses": [dict(interface="en0", address="10.0.0.20" if good else "100.72.1.5"),
                                dict(interface="lo0", address="127.0.0.1")],
        "hash": [dict(path="/private/etc/hosts", sha256=DEFAULT_HOSTS_SHA if good else "abc")],
        "etc_hosts": [dict(address="127.0.0.1", hostnames="localhost")]
                     + ([] if good else [dict(address="10.9.9.9", hostnames="gs.apple.com")]),
        "plist": ([dict(path="/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound",
                        key="CloudConfigRecord", subkey="OrganizationName", value="Lab Org")] if good else [])
                 + ([] if good else [dict(path="/Library/Preferences/SystemConfiguration/preferences.plist",
                                          key="NetworkServices", subkey="ABC/Proxies/HTTPEnable", value="1")]),
        "wifi_status": [dict(network_name="", security_type="WPA3 Personal", channel=36, rssi=-50)] if good else [],
        "mdm": [dict(server_url="https://fleet.example/mdm/apple/mdm", enrolled="true",
                     installed_from_dep="true", user_approved="true")] if good else [],
        "curl": [dict(url="https://fleet.example/mdm/apple/mdm", response_code=405)],
        "managed_policies": ([dict(domain="com.apple.security.firewall", name="EnableFirewall", value="1", username=""),
                              dict(domain="com.apple.MCX", name="DisableGuestAccount", value="1", username=""),
                              dict(domain="com.apple.screensaver", name="askForPasswordDelay", value="5", username=""),
                              dict(domain="com.apple.security.FDERecoveryKeyEscrow", name="Location",
                                   value="Fleet", username="")] if good else
                             [dict(domain="com.apple.security.firewall", name="EnableFirewall", value="0", username=""),
                              dict(domain="com.apple.security.firewall", name="EnableFirewall", value="1", username="")]),
        "file_lines": [dict(path="/private/etc/ntp.conf", line="server time.apple.com" if good else "server ntp.corp")],
        "secureboot": [dict(description="Full Security" if good else "Reduced Security", secure_mode=None)],
        "users": [dict(uid=501, username="alex", shell="/bin/zsh"), dict(uid=502, username="sam", shell="/bin/zsh"),
                  dict(uid=4294967294, username="nobody", shell="/usr/bin/false")],
        "dscl": [dict(command="read", path="/Users/alex", key="AuthenticationAuthority",
                      value=";ShadowHash;HASHLIST:<SALTED-SHA512-PBKDF2>;SecureToken;"),
                 dict(command="read", path="/Users/sam", key="AuthenticationAuthority",
                      value=";ShadowHash;HASHLIST:<SALTED-SHA512-PBKDF2>;" + (";SecureToken;" if good else "")),
                 dict(command="read", path="/Users/root", key="Password", value="*" if good else "********")],
        "file": [dict(path="/dev/console", uid=501)] + ([dict(path="/var/db/FileVaultPRK.dat", uid=0)] if good else []),
        "filevault_status": [dict(status="on" if good else "off")],
        "gatekeeper": [dict(assessments_enabled=int(yes))],
        "sip_config": [dict(config_flag="sip", enabled=int(yes))],
        "authdb": [dict(right_name="system.login.screensaver",
                        json_result=json.dumps({"rule": ["use-login-window-ui" if good else "authenticate-session-owner"]}))],
        "user_groups": [dict(uid=501, gid=20)] + ([] if good else [dict(uid=501, gid=80)]),
        "ad_config": [] if good else [dict(name="ad", domain="corp.example", option="x", value="y")],
        "kernel_extensions": [dict(name="com.apple.driver.X", version="1")]
                             + ([] if good else [dict(name="com.vendor.kext", version="2.0")]),
        "system_extensions": [dict(identifier="com.fleetdm.ext", state="activated_enabled")],
        "startup_items": [dict(name="com.vendor.agent", type="agent", path="/Library/LaunchAgents/x.plist")],
        "apps": [dict(path="/Applications/Good.app"), dict(path="/Applications/Old.app")],
        "signature": [dict(path="/Applications/Good.app", arch="arm64", signed=1, hash_resources=0, hash_executable=0),
                      dict(path="/Applications/Good.app", arch="x86_64", signed=1, hash_resources=0, hash_executable=0)]
                     + ([dict(path="/Applications/Old.app", arch="arm64", signed=1, hash_resources=0, hash_executable=0)]
                        if good else
                        [dict(path="/Applications/Old.app", arch="x86_64", signed=0, hash_resources=0, hash_executable=0)]),
    }


# (meu_id, expected result on the compliant host, on the non-compliant host)
EXPECT = [
    ("CI_assess-CoProcessor_Version", "PASS", "WARN"),
    ("NI_assess-Private_IP_Address", "PASS", "WARN"),
    ("NI_assess-Host_File_Status", "PASS", "FAIL"),
    ("NI_assess-Proxy_Information", "INFO", "INFO"),
    ("MM_assess-Organization_Name", "PASS", "FAIL"),
    ("MM_assess-MDM_Server_URL", "PASS", "FAIL"),
    ("MM_assess-MDM_External_Reachability", "PASS", "FAIL"),
    ("MM_assess-Automated_Device_Enrollment", "PASS", "INFO"),
    ("MM_assess-MDM_Enrollment_Type", "PASS", "INFO"),
    ("MM_assess-Firewall_Configuration", "PASS", "WARN"),
    ("MM_assess-Guest_Account_Configuration", "PASS", "FAIL"),
    ("MM_assess-Screen_Saver_Ask_For_Password_Configuration", "PASS", "FAIL"),
    ("MM_assess-NetworkTimeConfiguration", "PASS", "WARN"),
    ("MM_assess-Secure_Boot", "PASS", "FAIL"),
    ("MM_assess-Secure_Token", "PASS", "FAIL"),
    ("MM_assess-File_Vault_Recovery_Key_Escrow_Configuration", "PASS", "FAIL"),
    ("MM_assess-FileVault_Status", "PASS", "WARN"),
    ("MM_assess-Gatekeeper_Status", "PASS", "WARN"),
    ("MM_assess-SIP_Status", "PASS", "FAIL"),
    ("MM_assess-Root_User_Status", "PASS", "FAIL"),
    ("KI_assess-KEXTs", "PASS", "WARN"),
    ("AI_assess-Unsigned_Apps", "PASS", "FAIL"),
    ("AI_assess-Intel_Only_Apps", "PASS", "INFO"),
]
EXPECT_VALUE = [
    ("MM_assess-User-Type", "standard", "admin"),
    ("MM_assess-AuthDB_Mods", "The authorization database has not been modified", None),
    ("IDM_AD_assess-AD_Computer_Info", "Not bound to Active Directory", "Bound to corp.example"),
    ("MM_assess-Secure_Token", "All users have a secure token", "Users without secure tokens: sam"),
]


def network_fixture(reports, good):
    """curl_certificate and curl rows for every host the reports test.

    Non-compliant: the first TLS host and first HTTP host don't answer, the second TLS host
    offers TLS 1.1, and a TLS inspection proxy signs the courier host."""
    text = "\n".join(r["query"] for r in reports)
    hosts = sorted(set(re.findall(r"'([a-z0-9.-]+:\d+)'", text)))
    urls = sorted(set(re.findall(r"'(http://[a-z0-9.-]+/)'", text)))
    certs = [dict(hostname=h, timeout=3, tls_version="TLSv1.3", issuer_organization="Apple Inc.") for h in hosts]
    responses = [dict(url=u, response_code=200) for u in urls]
    if not good:
        certs = certs[1:]
        certs[0]["tls_version"] = "TLSv1.1"
        for c in certs:
            if c["hostname"] == "courier.push.apple.com:443":
                c["issuer_organization"] = "Inspecting Proxy Inc."
        responses = responses[1:]
    return {"curl_certificate": certs, "curl": responses}, hosts, urls


def build_db(schema, fixture):
    db = sqlite3.connect(":memory:")
    for t in schema:
        if t["name"] in fixture:
            cols = [c["name"] for c in t["columns"]]
            db.execute(f'CREATE TABLE "{t["name"]}" ({", ".join(chr(34) + c + chr(34) for c in cols)})')
            for row in fixture[t["name"]]:
                unknown = set(row) - set(cols)
                if unknown:
                    sys.exit(f"fixture for {t['name']} uses columns not in Fleet's schema: {unknown}")
                db.execute(f'INSERT INTO "{t["name"]}" ({", ".join(row)}) VALUES ({", ".join("?" * len(row))})',
                           list(row.values()))
    return db


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--schema", default=DEFAULT_SCHEMA)
    ap.add_argument("--reports", default=os.path.join(REPO, "lib/macos/reports/mac-evaluation-utility.reports.yml"))
    args = ap.parse_args()
    schema = json.load(open(args.schema))
    reports = yaml.safe_load(open(args.reports))
    failures = 0
    for label, good in (("compliant", True), ("non-compliant", False)):
        fixture = common(good)
        net, hosts, urls = network_fixture(reports, good)
        fixture["curl"] = fixture["curl"] + net["curl"]
        fixture["curl_certificate"] = net["curl_certificate"]
        missing = set(fixture) - {t["name"] for t in schema}
        if missing:
            sys.exit(f"fixture tables not in Fleet's schema: {missing}")
        results, all_rows = {}, []
        for r in reports:
            db = build_db(schema, fixture)
            try:
                cur = db.execute(r["query"])
            except sqlite3.Error as e:
                print(f"FAIL {r['name']}: {e}")
                failures += 1
                continue
            cols = [d[0] for d in cur.description]
            if cols != ["meu_id", "category", "test", "result", "value"]:
                print(f"FAIL {r['name']}: columns are {cols}")
                failures += 1
            rows = cur.fetchall()
            bad = [row for row in rows if row[3] not in ("PASS", "WARN", "FAIL", "INFO")]
            if bad:
                print(f"FAIL {r['name']}: unexpected result values {bad[:3]}")
                failures += 1
            print(f"ok   {label:<13} {r['name']}: {len(rows)} rows")
            for row in rows:
                results.setdefault(row[0], row)
            all_rows.extend(rows)
        for meu_id, want_good, want_bad in EXPECT:
            want = want_good if good else want_bad
            got = results.get(meu_id)
            if got is None or got[3] != want:
                print(f"FAIL {label} {meu_id}: want {want}, got {got and got[3:]}")
                failures += 1
        for meu_id, want_good, want_bad in EXPECT_VALUE:
            want = want_good if good else want_bad
            got = results.get(meu_id)
            if want is not None and (got is None or got[4] != want):
                print(f"FAIL {label} {meu_id}: want value {want!r}, got {got and got[4]!r}")
                failures += 1
        # Network: every host passes on the compliant fixture; on the other, exactly the planted faults show.
        net_rows = [row for row in all_rows if row[0].startswith(("NC_", "ANR_"))]
        counts = {k: sum(1 for row in net_rows if row[3] == k) for k in ("PASS", "WARN", "FAIL")}
        want = {"WARN": 0, "FAIL": 0} if good else {"WARN": 1, "FAIL": None}
        intercept = [row for row in net_rows if row[0] == "ANR_assess-HTTPS_Interception"]
        print(f"     {label:<13} network rows {len(net_rows)}: {counts}; interception {intercept[0][3:] if intercept else None}")
        if counts["WARN"] != want["WARN"] or (good and counts["FAIL"]) or (not good and counts["FAIL"] < 3):
            print(f"FAIL {label} network counts {counts}")
            failures += 1
        if not intercept or intercept[0][3] != ("PASS" if good else "FAIL"):
            print(f"FAIL {label} interception row {intercept}")
            failures += 1
    checked = len(EXPECT) + len(EXPECT_VALUE) + 2
    print(f"\n{'FAILED' if failures else 'PASSED'}: {failures} failure(s); {checked} checks per fixture")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
