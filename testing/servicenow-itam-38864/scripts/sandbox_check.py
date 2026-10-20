#!/usr/bin/env python3
"""Checks one package's native report row against ground truth.

Used by run-sandbox-linux.sh, where there is no Fleet server: rows come straight from
osquery shell mode, so this checks collection, not Fleet ingestion or the exporter.

Usage:
  sandbox_check.py date      <gt.tsv> <event> <pkg> <native.json> <date_col>
  sandbox_check.py publisher <gt.tsv> <pkg> <native.json> <publisher_col>
  sandbox_check.py absent    <pkg> <native.json>
  sandbox_check.py coverage  <native.json> <date_col> <publisher_col>

Prints what it compared and exits 0 for PASS, 1 for FAIL.
"""
import csv
import datetime as dt
import json
import re
import sys

# Same match rule as compare.py: two minutes for second-precision sources.
TOLERANCE = 120


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return []


def gt_rows(path, pkg):
    with open(path) as f:
        return [r for r in csv.DictReader(f, delimiter='\t') if r['app'] == pkg]


def utc(s):
    return int(dt.datetime.strptime(s, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=dt.timezone.utc).timestamp())


def iso(ts):
    return dt.datetime.fromtimestamp(int(ts), dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ') if ts else '(empty)'


def row_for(rows, pkg):
    return next((r for r in rows if r.get('name') == pkg), None)


def name_only(s):
    # dpkg's Maintainer is "Name <address>". The exporter sends the name only.
    return re.sub(r'\s*<[^>]*>\s*$', '', s or '').strip()


def cmd_date(a):
    gt, event, pkg, native, col = a
    ev = [r for r in gt_rows(gt, pkg) if r['event'] == event]
    if not ev:
        print('FAIL no ground truth for %s %s' % (event, pkg))
        return 1
    want = utc(ev[-1]['utc'])
    n = row_for(load(native), pkg)
    got = int(n[col]) if n and n.get(col) else 0
    print('native %s %s  ground truth %s %s  delta %+ds' % (col, iso(got), event, iso(want), got - want))
    ok = bool(got) and abs(got - want) <= TOLERANCE
    print('match' if ok else 'no match')
    return 0 if ok else 1


def cmd_publisher(a):
    gt, pkg, native, col = a
    want = next((r['expected_publisher'] for r in gt_rows(gt, pkg) if r['event'] == 'install'), '')
    n = row_for(load(native), pkg) or {}
    got = name_only(n.get(col))
    print('expected %r  got %r  (raw %r)' % (name_only(want), got, n.get(col)))
    return 0 if want and got == name_only(want) else 1


def cmd_absent(a):
    pkg, native = a
    present = row_for(load(native), pkg) is not None
    print('native row: %s' % ('present' if present else 'absent'))
    return 1 if present else 0


def cmd_coverage(a):
    native, dcol, pcol = a
    rows = load(native)

    def pct(f):
        return (100.0 * sum(1 for r in rows if f(r)) / len(rows)) if rows else 0.0

    print('rows          %d' % len(rows))
    print('install date  %.1f%%' % pct(lambda r: r.get(dcol) not in (None, '', '0')))
    print('publisher     %.1f%%' % pct(lambda r: name_only(r.get(pcol)) not in ('', '(none)')))
    return 0 if rows else 1


if __name__ == '__main__':
    cmds = {'date': cmd_date, 'publisher': cmd_publisher, 'absent': cmd_absent, 'coverage': cmd_coverage}
    if len(sys.argv) < 2 or sys.argv[1] not in cmds:
        print(__doc__)
        sys.exit(2)
    sys.exit(cmds[sys.argv[1]](sys.argv[2:]))
