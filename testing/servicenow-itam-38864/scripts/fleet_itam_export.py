#!/usr/bin/env python3
"""Exporter prototype: Fleet hosts and software to ServiceNow ITAM rows (fleetdm/fleet#38864).

Usage:
  FLEET_URL=https://fleet.example FLEET_API_TOKEN=... \\
    fleet_itam_export.py --fleet-id 7 [--out DIR] [--state FILE] [--per-page 500]
  Add --post --snow-instance dev12345 [--snow-table u_fleet_sw_install] to load ServiceNow.
  SNOW_USER and SNOW_PASSWORD come from the environment. Without --post nothing leaves this machine.

FLEET_URL and FLEET_API_TOKEN are read from the environment, or from the KEY=VALUE file in SECRETS_ENV.

Writes:
  <out>/hosts/<host_id>.json   host fields from the issue plus every software row with all date candidates
  <out>/snow_rows.json, .csv   one row per installed software, shaped for cmdb_sam_sw_install
  <state>                      first seen dates, kept between runs

Python 3 standard library only, so it runs anywhere the tests run.
"""
import argparse
import base64
import csv
import datetime as dt
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

# Report names as declared in lib/*/reports/software-itam.reports.yml.
REPORTS = {
    'mac_install': 'ITAM macOS app install date',
    'mac_publisher': 'ITAM macOS app publisher',
    'mac_receipts': 'ITAM macOS package receipts',
    'win_programs': 'ITAM Windows program install date and publisher',
    'win_keys': 'ITAM Windows uninstall key written',
    'rpm': 'ITAM Linux RPM install date and vendor',
    'deb': 'ITAM Linux DEB install date and maintainer',
}

# The sources the issue asks about. Other sources (browser extensions, Homebrew, Python packages)
# are not apps in the ITAM sense and would flood ServiceNow.
ITAM_SOURCES = {'apps', 'programs', 'rpm_packages', 'deb_packages'}

# Sources that only carry a day. compare.py uses the same set for its match rule.
DAY_PRECISION = {'registry_install_date'}

SNOW_FIELDS = [
    'installed_on_serial', 'installed_on_name', 'display_name', 'version', 'source',
    'publisher', 'publisher_source', 'install_date', 'install_date_source', 'first_seen',
    'last_used', 'last_used_source', 'install_location',
]


# ---------- Fleet API ----------

def load_secrets(path):
    out = {}
    if path and os.path.exists(path):
        with open(path) as f:
            lines = f.read().splitlines()
        for line in lines:
            line = line.strip()
            if '=' in line and not line.startswith('#'):
                k, v = line.split('=', 1)
                out[k.strip()] = v.strip().strip('"').strip("'")
    return out


class Fleet:
    def __init__(self, url, token, per_page=500):
        self.url = url.rstrip('/')
        self.token = token
        self.per_page = per_page

    def get(self, path, params=None):
        q = urllib.parse.urlencode({k: v for k, v in (params or {}).items() if v is not None})
        req = urllib.request.Request(self.url + path + ('?' + q if q else ''))
        req.add_header('Authorization', 'Bearer ' + self.token)
        req.add_header('Accept', 'application/json')
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.load(r)

    def pages(self, path, key, params=None):
        """Yield every item of a paginated list. Stops on meta.has_next_results false, or on a short page
        for endpoints that don't return meta."""
        page = 0
        while True:
            p = dict(params or {}, page=page, per_page=self.per_page)
            body = self.get(path, p)
            items = body.get(key)
            if items is None and key == 'reports':
                items = body.get('queries')  # List reports returns both keys in 4.93; older servers only "queries".
            items = items or []
            yield from items
            meta = body.get('meta')
            if meta is not None:
                if not meta.get('has_next_results'):
                    return
            elif len(items) < self.per_page:
                return
            page += 1

    # Docs: "List hosts" (fleet_id, populate_end_users).
    def hosts(self, fleet_id):
        return list(self.pages('/api/v1/fleet/hosts', 'hosts', {'fleet_id': fleet_id, 'populate_end_users': 'true'}))

    # Docs: "Get host's software".
    def host_software(self, host_id):
        return list(self.pages('/api/v1/fleet/hosts/%d/software' % host_id, 'software'))

    # Docs: "List reports" (fleet_id, merge_inherited).
    def reports(self, fleet_id):
        return list(self.pages('/api/v1/fleet/reports', 'reports', {'fleet_id': fleet_id, 'merge_inherited': 'true'}))

    # Docs: "Get report data". page applies only with per_page; meta is returned when per_page is set.
    def report_rows(self, report_id, fleet_id):
        return list(self.pages('/api/v1/fleet/reports/%d/report' % report_id, 'results', {'fleet_id': fleet_id}))


# ---------- Normalizers ----------

def epoch_to_dt(v):
    try:
        n = int(float(v))
    except (TypeError, ValueError):
        return None
    if n <= 0:
        return None
    return dt.datetime.fromtimestamp(n, dt.timezone.utc)


def parse_any_date(v):
    """Turn the date shapes the sources use into a UTC datetime, or None."""
    if v in (None, '', '0'):
        return None
    s = str(v).strip()
    if re.fullmatch(r'\d{9,11}(\.\d+)?', s):
        return epoch_to_dt(s)
    if re.fullmatch(r'\d{8}', s):  # Windows InstallDate, YYYYMMDD, local day
        try:
            return dt.datetime.strptime(s, '%Y%m%d').replace(tzinfo=dt.timezone.utc)
        except ValueError:
            return None
    for fmt in ('%Y-%m-%d %H:%M:%S %z', '%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%dT%H:%M:%S%z', '%Y-%m-%d %H:%M:%S'):
        try:
            d = dt.datetime.strptime(s, fmt)
            return d if d.tzinfo else d.replace(tzinfo=dt.timezone.utc)
        except ValueError:
            pass
    return None


def fmt(d):
    # ServiceNow glide date time format, UTC.
    return d.strftime('%Y-%m-%d %H:%M:%S') if d else ''


def macos_publisher(authority):
    """Signing certificate name to a publisher name. App Store apps are signed by Apple for every
    developer, so that certificate says nothing about the publisher."""
    a = (authority or '').strip()
    if not a:
        return ''
    if a == 'Software Signing':
        return 'Apple'
    if a.startswith('Apple Mac OS Application Signing'):
        return ''
    m = re.match(r'^(?:Developer ID Application|Apple Development|Apple Distribution|Mac Developer):\s*(.+?)(?:\s*\([A-Z0-9]{10}\))?$', a)
    return m.group(1).strip() if m else a


# ---------- Join ----------

def index_reports(rows_by_report):
    """Group report rows by host, keyed the way each OS joins back to the software API."""
    idx = {}

    def put(name, host_id, key, cols):
        idx.setdefault(name, {}).setdefault(host_id, {})[key] = cols

    for r in rows_by_report.get('mac_install', []):
        put('mac_install', r['host_id'], r['columns'].get('path', ''), r['columns'])
    for r in rows_by_report.get('mac_publisher', []):
        # Universal apps can return one row per architecture. The first non-empty authority wins.
        c = r['columns']
        cur = idx.get('mac_publisher', {}).get(r['host_id'], {}).get(c.get('path', ''))
        if not cur or (not cur.get('authority') and c.get('authority')):
            put('mac_publisher', r['host_id'], c.get('path', ''), c)
    for r in rows_by_report.get('win_keys', []):
        # name is the Uninstall subkey, the same value as programs.identifying_number.
        put('win_keys', r['host_id'], r['columns'].get('name', ''), r['columns'])
    for name in ('win_programs', 'rpm', 'deb'):
        for r in rows_by_report.get(name, []):
            c = r['columns']
            put(name, r['host_id'], (c.get('name', ''), c.get('version', '')), c)
    return idx


def software_rows(host, software, idx, state, now):
    """One row per installed copy of each ITAM software item, with every date candidate kept."""
    hid = host['id']
    serial = host.get('hardware_serial') or ''
    rows = []
    for title in software:
        source = title.get('source', '')
        if source not in ITAM_SOURCES:
            continue
        for iv in title.get('installed_versions') or []:
            version = iv.get('version', '')
            paths = iv.get('installed_paths') or ['']
            for path in paths:
                key = path if source == 'apps' else (title.get('name', ''), version)
                cands = {}
                publisher, publisher_source = '', ''

                if source == 'apps':
                    ni = idx.get('mac_install', {}).get(hid, {}).get(path, {})
                    for col, src in (('date_added', 'spotlight_date_added'), ('bundle_created', 'bundle_created')):
                        d = parse_any_date(ni.get(col))
                        if d:
                            cands.setdefault('native:' + src, d)
                    np = idx.get('mac_publisher', {}).get(hid, {}).get(path, {})
                    publisher = macos_publisher(np.get('authority'))
                    publisher_source = 'native:codesign_authority' if publisher else ''
                elif source == 'programs':
                    n = idx.get('win_programs', {}).get(hid, {}).get(key, {})
                    d = parse_any_date(n.get('install_date'))
                    if d:
                        cands.setdefault('native:registry_install_date', d)
                    kw = idx.get('win_keys', {}).get(hid, {}).get(n.get('identifying_number', ''), {})
                    d = parse_any_date(kw.get('key_written'))
                    if d:
                        cands.setdefault('native:registry_key_written', d)
                    if n.get('publisher'):
                        publisher, publisher_source = n['publisher'], 'native:registry_publisher'
                elif source == 'rpm_packages':
                    n = idx.get('rpm', {}).get(hid, {}).get(key, {})
                    d = parse_any_date(n.get('install_time'))
                    if d:
                        cands.setdefault('native:rpm_install_time', d)
                    if n.get('vendor'):
                        publisher, publisher_source = n['vendor'], 'native:rpm_vendor'
                elif source == 'deb_packages':
                    n = idx.get('deb', {}).get(hid, {}).get(key, {})
                    d = parse_any_date(n.get('list_changed'))
                    if d:
                        cands.setdefault('native:dpkg_list_changed', d)
                    if n.get('maintainer'):
                        publisher, publisher_source = n['maintainer'], 'native:deb_maintainer'

                # dpkg's Maintainer field is "Name <list address>". ServiceNow wants the name only.
                if publisher_source.endswith('deb_maintainer'):
                    publisher = re.sub(r'\s*<[^>]*>\s*$', '', publisher)

                # First seen by this exporter, kept in the state file between runs. RPM install_time and
                # DEB list_changed move on every upgrade and reinstall (sandbox run, 2026-10-20), so this is
                # the only date that stays put. It goes to ServiceNow as its own column, next to install_date.
                skey = '%s|%s|%s|%s' % (serial or hid, source, title.get('name', ''), path)
                fs = state.setdefault(skey, fmt(now))
                first_seen = parse_any_date(fs)
                cands['exporter_first_seen'] = first_seen

                # Preference: native report dates in this order, then first seen.
                install, install_src = None, ''
                for src in ('native:registry_install_date', 'native:registry_key_written', 'native:rpm_install_time',
                            'native:spotlight_date_added', 'native:dpkg_list_changed', 'native:bundle_created'):
                    if src in cands:
                        install, install_src = cands[src], src
                        break
                else:
                    install, install_src = first_seen, 'exporter_first_seen'

                last = parse_any_date(iv.get('last_opened_at'))
                rows.append({
                    'host_id': hid,
                    'installed_on_serial': serial,
                    'installed_on_name': host.get('display_name') or host.get('hostname') or '',
                    'display_name': title.get('name', ''),
                    'version': version,
                    'source': source,
                    'bundle_identifier': iv.get('bundle_identifier') or '',
                    'publisher': publisher,
                    'publisher_source': publisher_source,
                    'install_date': fmt(install),
                    'install_date_source': install_src,
                    'first_seen': fmt(first_seen),
                    'last_used': fmt(last),
                    'last_used_source': 'fleet:last_opened_at' if last else '',
                    'install_location': path,
                    'candidates': {k: fmt(v) for k, v in sorted(cands.items())},
                })
    return rows


def host_fields(h):
    """The host fields #38864 lists, from List hosts with populate_end_users."""
    eu = (h.get('end_users') or [{}])[0] or {}
    return {
        'id': h.get('id'),
        'name': h.get('display_name') or h.get('computer_name') or h.get('hostname') or '',
        'hostname': h.get('hostname') or '',
        'platform': h.get('platform') or '',
        'os_version': h.get('os_version') or '',
        'serial': h.get('hardware_serial') or '',
        'manufacturer': h.get('hardware_vendor') or '',
        'model': h.get('hardware_model') or '',
        'idp_username': eu.get('idp_username') or '',
        'idp_full_name': eu.get('idp_full_name') or '',
        'idp_department': eu.get('idp_department') or '',
        'last_seen': h.get('seen_time') or '',
    }


# ---------- ServiceNow ----------

def post_snow(instance, table, rows, user, password, batch=200):
    """Import Set API, insertMultiple. A transform map on the staging table writes cmdb_sam_sw_install."""
    url = 'https://%s.service-now.com/api/now/import/%s/insertMultiple' % (instance, table)
    auth = base64.b64encode(('%s:%s' % (user, password)).encode()).decode()
    sent = 0
    for i in range(0, len(rows), batch):
        body = json.dumps({'records': [{k: r[k] for k in SNOW_FIELDS} for r in rows[i:i + batch]]}).encode()
        req = urllib.request.Request(url, data=body, method='POST')
        req.add_header('Authorization', 'Basic ' + auth)
        req.add_header('Content-Type', 'application/json')
        req.add_header('Accept', 'application/json')
        with urllib.request.urlopen(req, timeout=120) as r:
            r.read()
        sent += len(rows[i:i + batch])
    return sent


# ---------- Main ----------

def run(fleet, fleet_id, out, state_path, now=None):
    now = now or dt.datetime.now(dt.timezone.utc)
    state = {}
    if state_path and os.path.exists(state_path):
        with open(state_path) as f:
            state = json.load(f)

    by_name = {r.get('name'): r.get('id') for r in fleet.reports(fleet_id)}
    rows_by_report, report_meta = {}, {}
    for key, name in REPORTS.items():
        rid = by_name.get(name)
        if rid is None:
            report_meta[key] = {'name': name, 'id': None, 'rows': 0}
            continue
        rows = fleet.report_rows(rid, fleet_id)
        rows_by_report[key] = rows
        report_meta[key] = {'name': name, 'id': rid, 'rows': len(rows)}
    idx = index_reports(rows_by_report)

    os.makedirs(os.path.join(out, 'hosts'), exist_ok=True)
    all_rows = []
    for h in fleet.hosts(fleet_id):
        sw = fleet.host_software(h['id'])
        rows = software_rows(h, sw, idx, state, now)
        all_rows.extend(rows)
        with open(os.path.join(out, 'hosts', '%d.json' % h['id']), 'w') as f:
            json.dump({'host': host_fields(h), 'software': rows}, f, indent=2, sort_keys=True)

    with open(os.path.join(out, 'snow_rows.json'), 'w') as f:
        json.dump([{k: r[k] for k in SNOW_FIELDS} for r in all_rows], f, indent=2)
    with open(os.path.join(out, 'snow_rows.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=SNOW_FIELDS, extrasaction='ignore')
        w.writeheader()
        w.writerows(all_rows)
    with open(os.path.join(out, 'reports.json'), 'w') as f:
        json.dump(report_meta, f, indent=2)
    if state_path:
        with open(state_path, 'w') as f:
            json.dump(state, f, indent=2, sort_keys=True)
    return all_rows, report_meta


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--fleet-id', type=int, required=True)
    ap.add_argument('--out', default='export-out')
    ap.add_argument('--state', default=None, help='first seen state file (default <out>/first_seen.json)')
    ap.add_argument('--per-page', type=int, default=500)
    ap.add_argument('--post', action='store_true', help='send rows to ServiceNow (default is a dry run)')
    ap.add_argument('--snow-instance')
    ap.add_argument('--snow-table', default='u_fleet_sw_install')
    a = ap.parse_args(argv)

    sec = load_secrets(os.environ.get('SECRETS_ENV'))
    url = os.environ.get('FLEET_URL') or sec.get('FLEET_URL')
    token = os.environ.get('FLEET_API_TOKEN') or sec.get('FLEET_API_TOKEN')
    if not url or not token:
        sys.exit('FLEET_URL and FLEET_API_TOKEN must be set (environment or SECRETS_ENV file)')

    rows, meta = run(Fleet(url, token, a.per_page), a.fleet_id, a.out, a.state or os.path.join(a.out, 'first_seen.json'))
    print('rows=%d hosts_dir=%s' % (len(rows), os.path.join(a.out, 'hosts')))
    for k, m in meta.items():
        print('report %-14s id=%s rows=%d %s' % (k, m['id'], m['rows'], '' if m['id'] else '(not found)'))

    if a.post:
        if not a.snow_instance:
            sys.exit('--post needs --snow-instance')
        user = os.environ.get('SNOW_USER') or sec.get('SNOW_USER')
        pw = os.environ.get('SNOW_PASSWORD') or sec.get('SNOW_PASSWORD')
        if not user or not pw:
            sys.exit('SNOW_USER and SNOW_PASSWORD must be set')
        print('posted=%d' % post_snow(a.snow_instance, a.snow_table, rows, user, pw))
    else:
        print('dry run: nothing sent to ServiceNow')


if __name__ == '__main__':
    main()
