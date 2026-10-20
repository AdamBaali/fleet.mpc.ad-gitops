"""Fake Fleet API for the exporter tests. Serves fixtures/fleet.json with the pagination shapes of
Fleet 4.93: List hosts (no meta), host software and report data (meta.has_next_results), and
List reports (both "reports" and "queries" keys). Checks the bearer token on every request."""
import json
import os
import threading
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOKEN = 'test-token'
DATA = json.load(open(os.path.join(os.path.dirname(__file__), 'fixtures', 'fleet.json')))


def page(items, q, meta):
    if 'per_page' not in q:
        return items, None
    n, p = int(q['per_page'][0]), int(q.get('page', ['0'])[0])
    chunk = items[p * n:(p + 1) * n]
    return chunk, ({'has_next_results': (p + 1) * n < len(items), 'has_previous_results': p > 0} if meta else None)


class Handler(BaseHTTPRequestHandler):
    requests = []

    def log_message(self, *a):
        pass

    def send(self, code, body):
        d = json.dumps(body).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(d)

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(u.query)
        Handler.requests.append((u.path, q))
        if self.headers.get('Authorization') != 'Bearer ' + TOKEN:
            return self.send(401, {'message': 'unauthorized'})
        parts = u.path.strip('/').split('/')
        if u.path == '/api/v1/fleet/hosts':
            hosts = [dict(h) for h in DATA['hosts']]
            if q.get('populate_end_users', ['false'])[0] != 'true':
                for h in hosts:
                    h.pop('end_users', None)
            items, _ = page(hosts, q, False)
            return self.send(200, {'hosts': items})
        if len(parts) == 5 and parts[3] == 'hosts':
            h = next((dict(x) for x in DATA['hosts'] if str(x['id']) == parts[4]), None)
            if h is None:
                return self.send(404, {'message': 'not found'})
            return self.send(200, {'host': h})
        if len(parts) == 7 and parts[3] == 'hosts' and parts[5] == 'reports':
            rows = [{'columns': r['columns']} for r in DATA['report_rows'].get(parts[6], []) if str(r['host_id']) == parts[4]]
            return self.send(200, {'report_id': int(parts[6]), 'host_id': int(parts[4]), 'report_clipped': False, 'results': rows})
        if len(parts) == 6 and parts[3] == 'hosts' and parts[5] == 'software':
            items, meta = page(DATA['software'].get(parts[4], []), q, True)
            body = {'count': len(DATA['software'].get(parts[4], [])), 'software': items}
            if meta:
                body['meta'] = meta
            return self.send(200, body)
        if u.path == '/api/v1/fleet/reports':
            items, meta = page(DATA['reports'], q, True)
            return self.send(200, {'reports': items, 'queries': items, 'meta': meta or {'has_next_results': False}})
        if len(parts) == 6 and parts[3] == 'reports' and parts[5] == 'report':
            rows = DATA['report_rows'].get(parts[4], [])
            items, meta = page(rows, q, True)
            body = {'report_id': int(parts[4]), 'report_clipped': False, 'count': len(rows), 'results': items}
            if meta:
                body['meta'] = meta
            return self.send(200, body)
        return self.send(404, {'message': 'not found'})


def start():
    srv = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv, 'http://127.0.0.1:%d' % srv.server_address[1]
