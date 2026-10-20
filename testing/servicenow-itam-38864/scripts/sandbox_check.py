#!/usr/bin/env python3
"""Checks one package's native report row and software_itam row against ground truth.

Used by run-sandbox-linux.sh, where there is no Fleet server: rows come straight from
osquery shell mode, so this checks collection, not Fleet ingestion or the exporter.

Usage:
  sandbox_check.py date   <gt.tsv> <event> <pkg> <native.json> <native_col> <ext.json> [--ext-expect first|event]
  sandbox_check.py absent <pkg> <native.json> <ext.json>
  sandbox_check.py coverage <native.json> <date_col> <publisher_col> <ext.json> <source>
  sandbox_check.py publisher <gt.tsv> <pkg> <ext.json>

Prints what it compared and exits 0 for PASS, 1 for FAIL.
"""
import csv
import datetime as dt
import json
import sys

# Same match rule as compare.py: two minutes for second-precision sources.
TOLERANCE = 120


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return []


def gt_times(path, pkg):
    with open(path) as f:
        rows = [r for r in csv.DictReader(f, delimiter='\t') if r['app'] == pkg]
    return rows


def utc(s):
    return int(dt.datetime.strptime(s, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=dt.timezone.utc).timestamp())


def iso(ts):
    return dt.datetime.fromtimestamp(int(ts), dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ') if ts else '(empty)'


def row_for(rows, pkg, key='name'):
    return next((r for r in rows if r.get(key) == pkg or r.get('identifier') == pkg), None)


def cmd_date(a):
    gt, event, pkg, native, col, ext = a[:6]
    expect = a[7] if len(a) > 7 and a[6] == '--ext-expect' else 'event'
    rows = gt_times(gt, pkg)
    ev = [r for r in rows if r['event'] == event]
    if not ev:
        print('FAIL no ground truth for %s %s' % (event, pkg))
        return 1
    want_event = utc(ev[-1]['utc'])
    first = utc(next(r for r in rows if r['event'] == 'install')['utc'])
    ok = True

    n = row_for(load(native), pkg)
    nv = int(n[col]) if n and n.get(col) else 0
    nd = nv - want_event
    print('native %-14s %s  ground truth %s %s  delta %+ds' % (col, iso(nv), event, iso(want_event), nd))
    native_ok = bool(nv) and abs(nd) <= TOLERANCE
    print('  native: %s' % ('match' if native_ok else 'no match'))

    e = row_for(load(ext), pkg)
    want_ext = first if expect == 'first' else want_event
    if not e:
        print('ext    no software_itam row')
        return 1
    ev_ = int(e.get('install_date') or 0)
    ed = ev_ - want_ext
    print('ext    install_date   %s  (%s)  want %s %s  delta %+ds' % (
        iso(ev_), e.get('install_date_source'), 'first install' if expect == 'first' else event, iso(want_ext), ed))
    print('       candidates     %s' % e.get('install_date_candidates'))
    print('       first_seen     %s' % iso(e.get('first_seen')))
    ext_ok = bool(ev_) and abs(ed) <= TOLERANCE
    print('  ext: %s' % ('match' if ext_ok else 'no match'))
    ok = native_ok and ext_ok
    return 0 if ok else 1


def cmd_absent(a):
    pkg, native, ext = a
    n, e = row_for(load(native), pkg), row_for(load(ext), pkg)
    print('native row: %s' % ('present' if n else 'absent'))
    print('ext row:    %s' % ('present' if e else 'absent'))
    return 0 if not n and not e else 1


def cmd_coverage(a):
    native, dcol, pcol, ext, source = a
    nrows, erows = load(native), [r for r in load(ext) if r.get('source') == source]

    def pct(rows, f):
        return (100.0 * sum(1 for r in rows if f(r)) / len(rows)) if rows else 0.0

    print('rows            native %6d   ext %6d' % (len(nrows), len(erows)))
    print('install date    native %5.1f%%   ext %5.1f%%' % (
        pct(nrows, lambda r: r.get(dcol) not in (None, '', '0')),
        pct(erows, lambda r: r.get('install_date') not in (None, '', '0'))))
    print('publisher       native %5.1f%%   ext %5.1f%%' % (
        pct(nrows, lambda r: (r.get(pcol) or '').strip() not in ('', '(none)')),
        pct(erows, lambda r: (r.get('publisher') or '').strip() != '')))
    srcs = {}
    for r in erows:
        srcs[r.get('install_date_source') or '(none)'] = srcs.get(r.get('install_date_source') or '(none)', 0) + 1
    print('ext install_date_source counts: %s' % json.dumps(srcs, sort_keys=True))
    # Row counts within 5% is the X-3 rule.
    return 0 if nrows and abs(len(erows) - len(nrows)) <= 0.05 * len(nrows) else 1


def cmd_publisher(a):
    gt, pkg, ext = a
    want = next((r['expected_publisher'] for r in gt_times(gt, pkg) if r['event'] == 'install'), '')
    e = row_for(load(ext), pkg) or {}
    got = (e.get('publisher') or '').split(' <')[0].strip()
    print('expected %r  got %r  (source %s)' % (want, e.get('publisher'), e.get('publisher_source')))
    return 0 if want and got == want.split(' <')[0].strip() else 1


if __name__ == '__main__':
    cmds = {'date': cmd_date, 'absent': cmd_absent, 'coverage': cmd_coverage, 'publisher': cmd_publisher}
    if len(sys.argv) < 2 or sys.argv[1] not in cmds:
        print(__doc__)
        sys.exit(2)
    sys.exit(cmds[sys.argv[1]](sys.argv[2:]))
