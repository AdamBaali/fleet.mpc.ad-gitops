#!/usr/bin/env python3
"""Compare ground truth with exporter output and write a verdict per check (fleetdm/fleet#38864).

Usage: compare.py --gt ground-truth/*.tsv --export export-out [--out verdicts] [--tolerance 120]

Ground truth TSV columns (written by gt-macos.sh, gt-linux.sh, gt-windows.ps1):
  test_id host os app key version method event utc expected_publisher note
  key is the app path on macOS and the program or package name elsewhere.
  event is install, open, upgrade, reinstall or uninstall. utc is ISO 8601 UTC.

Match rules (TEST_PLAN.md, "Ground truth"):
  install, reinstall  the chosen install_date is within the tolerance of utc. Day-precision sources
                      (Windows InstallDate) match when the day is within one day, since the registry
                      stores the host's local day.
  open                last_used is within the tolerance of utc.
  upgrade             PASS when install_date still matches the first install (first installed date),
                      PARTIAL when it moved to the upgrade time (a last changed date). Both are recorded.
  uninstall           PASS when the row is gone.
  expected_publisher  PASS when the publisher contains it, case-insensitive.
Every date candidate that matched is listed, so one run answers which source to trust.

Reads files only. Calls nothing external.
"""
import argparse
import csv
import datetime as dt
import glob
import json
import os
import sys

DAY_PRECISION = ('registry_install_date',)


def parse(s):
    if not s:
        return None
    for f in ('%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%d %H:%M:%S', '%Y-%m-%dT%H:%M:%S%z', '%Y-%m-%dT%H:%M:%S.%fZ'):
        try:
            d = dt.datetime.strptime(s, f)
            return d if d.tzinfo else d.replace(tzinfo=dt.timezone.utc)
        except ValueError:
            pass
    return None


def close(a, b, source, tol):
    if not a or not b:
        return False
    if any(p in (source or '') for p in DAY_PRECISION):
        return abs((a.date() - b.date()).days) <= 1
    return abs((a - b).total_seconds()) <= tol


def load_gt(paths):
    rows = []
    for p in paths:
        with open(p, newline='') as f:
            for r in csv.DictReader(f, delimiter='\t'):
                if r.get('test_id', '').startswith('#') or not r.get('event'):
                    continue
                rows.append(r)
    rows.sort(key=lambda r: r['utc'])
    return rows


def load_export(d):
    hosts = []
    for p in sorted(glob.glob(os.path.join(d, 'hosts', '*.json'))):
        with open(p) as f:
            hosts.append(json.load(f))
    return hosts


def find_host(hosts, name):
    n = (name or '').lower()
    for h in hosts:
        hf = h['host']
        if n in {str(hf.get(k, '')).lower() for k in ('name', 'hostname', 'serial')} or n == str(hf.get('id')):
            return h
    return None


def find_rows(host, gt):
    key = gt['key']
    out = []
    for r in host['software']:
        if gt['os'] == 'macos':
            if r.get('install_location') == key:
                out.append(r)
        elif r.get('display_name', '').lower() == key.lower() or r.get('display_name', '').lower().startswith(key.lower()):
            if not gt.get('version') or not r.get('version') or r['version'].startswith(gt['version']):
                out.append(r)
    return out


def evaluate(gt_rows, hosts, tol=120):
    verdicts = []
    first_install = {}
    for g in gt_rows:
        t = parse(g['utc'])
        h = find_host(hosts, g['host'])
        base = {'test_id': g['test_id'], 'host': g['host'], 'app': g['app'], 'event': g['event'], 'gt_utc': g['utc']}
        if h is None:
            verdicts.append(dict(base, check='host', result='BLOCKED', detail='host not in export'))
            continue
        rows = find_rows(h, g)
        ident = (g['host'], g['key'])
        ev = g['event']

        if ev == 'uninstall':
            verdicts.append(dict(base, check='removed', result='FAIL' if rows else 'PASS',
                                 detail='%d row(s) still present' % len(rows) if rows else 'row gone'))
            continue
        if not rows:
            verdicts.append(dict(base, check=ev, result='FAIL', detail='no row for %s' % g['key']))
            continue
        r = rows[0]

        if ev in ('install', 'reinstall'):
            if ev == 'install':
                first_install.setdefault(ident, t)
            got = parse(r.get('install_date'))
            src = r.get('install_date_source', '')
            matched = [k for k, v in (r.get('candidates') or {}).items() if close(parse(v), t, k, tol)]
            ok = close(got, t, src, tol)
            verdicts.append(dict(base, check='install_date', result='PASS' if ok else 'FAIL',
                                 detail='chosen %s from %s; candidates matching: %s' % (
                                     r.get('install_date') or 'empty', src or 'none', ', '.join(matched) or 'none')))
            if g.get('expected_publisher'):
                pub = r.get('publisher', '')
                ok = g['expected_publisher'].lower() in pub.lower() if g['expected_publisher'] != '-' else pub == ''
                verdicts.append(dict(base, check='publisher', result='PASS' if ok else 'FAIL',
                                     detail='got "%s" from %s, expected "%s"' % (pub, r.get('publisher_source') or 'none', g['expected_publisher'])))
        elif ev == 'open':
            got = parse(r.get('last_used'))
            ok = close(got, t, '', tol)
            verdicts.append(dict(base, check='last_used', result='PASS' if ok else 'FAIL',
                                 detail='last_used %s' % (r.get('last_used') or 'empty')))
        elif ev == 'upgrade':
            got = parse(r.get('install_date'))
            first = first_install.get(ident)
            if first and close(got, first, r.get('install_date_source', ''), tol):
                res, det = 'PASS', 'keeps first install (%s)' % r.get('install_date')
            elif close(got, t, r.get('install_date_source', ''), tol):
                res, det = 'PARTIAL', 'moved to the upgrade time (%s): a last changed date' % r.get('install_date')
            else:
                res, det = 'FAIL', 'matches neither first install nor upgrade (%s)' % (r.get('install_date') or 'empty')
            verdicts.append(dict(base, check='install_date_after_upgrade', result=res,
                                 detail=det + ' from ' + (r.get('install_date_source') or 'none')))
        else:
            verdicts.append(dict(base, check=ev, result='INFO', detail='event not evaluated'))
    return verdicts


def write(verdicts, out):
    os.makedirs(out, exist_ok=True)
    cols = ['test_id', 'host', 'app', 'event', 'check', 'result', 'gt_utc', 'detail']
    with open(os.path.join(out, 'verdicts.tsv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=cols, delimiter='\t', extrasaction='ignore')
        w.writeheader()
        w.writerows(verdicts)
    with open(os.path.join(out, 'verdicts.md'), 'w') as f:
        f.write('| ' + ' | '.join(cols) + ' |\n|' + '---|' * len(cols) + '\n')
        for v in verdicts:
            f.write('| ' + ' | '.join(str(v.get(c, '')).replace('|', '/') for c in cols) + ' |\n')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--gt', nargs='+', required=True)
    ap.add_argument('--export', required=True)
    ap.add_argument('--out', default='verdicts')
    ap.add_argument('--tolerance', type=int, default=120)
    a = ap.parse_args(argv)
    v = evaluate(load_gt(a.gt), load_export(a.export), a.tolerance)
    write(v, a.out)
    counts = {}
    for x in v:
        counts[x['result']] = counts.get(x['result'], 0) + 1
    print(' '.join('%s=%d' % kv for kv in sorted(counts.items())) or 'no checks')
    return 0


if __name__ == '__main__':
    sys.exit(main())
