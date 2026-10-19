import csv
import datetime as dt
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, HERE)
import fake_fleet  # noqa: E402
import fleet_itam_export as ex  # noqa: E402

NOW = dt.datetime(2026, 10, 20, 12, 0, tzinfo=dt.timezone.utc)


class ExportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.srv, cls.url = fake_fleet.start()
        cls.tmp = tempfile.mkdtemp()
        fake_fleet.Handler.requests.clear()
        # per_page=2 forces several pages on every list.
        cls.rows, cls.meta = ex.run(ex.Fleet(cls.url, fake_fleet.TOKEN, per_page=2), 7, cls.tmp,
                                    os.path.join(cls.tmp, 'state.json'), now=NOW)
        cls.by = {}
        for f in os.listdir(os.path.join(cls.tmp, 'hosts')):
            d = json.load(open(os.path.join(cls.tmp, 'hosts', f)))
            cls.by[d['host']['hostname']] = d

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()
        cls.srv.server_close()

    def row(self, host, name, path=None):
        for r in self.by[host]['software']:
            if r['display_name'] == name and (path is None or r['install_location'] == path):
                return r
        self.fail('no row %s %s' % (name, path))

    def test_pagination_reaches_every_host_and_report(self):
        self.assertEqual(set(self.by), {'lab-mac.local', 'lab-win', 'lab-ubuntu', 'lab-fedora'})
        self.assertEqual(self.meta['mac_publisher']['rows'], 5)
        self.assertEqual(self.meta['ext']['rows'], 2)
        pages = [q.get('page') for p, q in fake_fleet.Handler.requests if p == '/api/v1/fleet/hosts']
        self.assertGreaterEqual(len(pages), 2)

    def test_fleet_filter_and_end_users_requested(self):
        q = [q for p, q in fake_fleet.Handler.requests if p == '/api/v1/fleet/hosts'][0]
        self.assertEqual(q['fleet_id'], ['7'])
        self.assertEqual(q['populate_end_users'], ['true'])

    def test_host_fields_from_issue(self):
        h = self.by['lab-mac.local']['host']
        for k in ('name', 'platform', 'os_version', 'serial', 'manufacturer', 'model', 'idp_username', 'idp_department', 'last_seen'):
            self.assertTrue(h[k], k)
        self.assertEqual(self.by['lab-win']['host']['serial'], '')  # VM: empty serial stays empty
        self.assertEqual(self.by['lab-win']['host']['idp_username'], '')

    def test_only_itam_sources(self):
        self.assertNotIn('git', [r['display_name'] for r in self.by['lab-mac.local']['software']])

    def test_macos_joins_on_path_one_row_per_copy(self):
        a = self.row('lab-mac.local', 'Google Chrome', '/Applications/Google Chrome.app')
        b = self.row('lab-mac.local', 'Google Chrome', '/Users/u/Applications/Google Chrome.app')
        self.assertEqual(a['install_date'], '2026-10-20 09:20:00')
        self.assertEqual(a['install_date_source'], 'native:spotlight_date_added')
        self.assertEqual(a['publisher'], 'Google LLC')
        self.assertEqual(b['install_date_source'], 'exporter_first_seen')
        self.assertEqual(b['publisher'], '')

    def test_macos_universal_app_first_nonempty_authority(self):
        r = self.row('lab-mac.local', 'VLC')
        self.assertEqual(r['publisher'], 'VideoLAN')
        self.assertEqual(r['last_used'], '2026-10-20 09:10:00')
        self.assertEqual(r['last_used_source'], 'fleet:last_opened_at')

    def test_publisher_normalization(self):
        self.assertEqual(self.row('lab-mac.local', 'Safari')['publisher'], 'Apple')
        self.assertEqual(ex.macos_publisher('Apple Mac OS Application Signing'), '')
        self.assertEqual(ex.macos_publisher('Developer ID Application: Example Inc (ABCDE12345)'), 'Example Inc')
        self.assertEqual(ex.macos_publisher(''), '')
        self.assertEqual(self.row('lab-mac.local', 'ITAMUnsigned')['publisher'], '')

    def test_extension_preferred_over_native(self):
        r = self.row('lab-mac.local', 'Pages')
        self.assertEqual(r['install_date_source'], 'ext:install_history')
        self.assertEqual(r['publisher'], 'Apple')
        self.assertEqual(r['publisher_source'], 'ext:copyright')
        self.assertIn('native:bundle_created', r['candidates'])
        d = self.row('lab-ubuntu', 'hello')
        self.assertEqual(d['install_date_source'], 'ext:dpkg_log')
        self.assertEqual(d['publisher_source'], 'native:deb_maintainer')

    def test_native_used_without_extension(self):
        r = self.row('lab-mac.local', 'VLC')
        self.assertEqual(r['install_date_source'], 'native:spotlight_date_added')
        f = self.row('lab-fedora', 'hello')
        self.assertEqual(f['install_date_source'], 'native:rpm_install_time')
        self.assertEqual(f['publisher'], 'Fedora Project')

    def test_windows_joins_on_name_and_version(self):
        r = self.row('lab-win', 'VLC media player')
        self.assertEqual(r['install_date'], '2026-10-20 00:00:00')
        self.assertEqual(r['install_date_source'], 'native:registry_install_date')
        self.assertEqual(r['publisher'], 'VideoLAN')
        n = self.row('lab-win', 'Notepad++ (64-bit x64)')
        self.assertEqual(n['install_date_source'], 'native:registry_key_written')
        self.assertEqual(n['install_date'], '2026-10-20 11:00:00')
        self.assertEqual(n['publisher'], 'Notepad++ Team')
        self.assertEqual(n['install_location'], '')

    def test_missing_fields_are_empty_with_no_source(self):
        r = self.row('lab-mac.local', 'Dialog')
        self.assertEqual(r['publisher'], '')
        self.assertEqual(r['publisher_source'], '')
        self.assertEqual(r['last_used'], '')
        self.assertEqual(r['last_used_source'], '')

    def test_snow_csv_shape(self):
        with open(os.path.join(self.tmp, 'snow_rows.csv')) as f:
            rd = csv.DictReader(f)
            self.assertEqual(rd.fieldnames, ex.SNOW_FIELDS)
            rows = list(rd)
        self.assertEqual(len(rows), len(self.rows))
        self.assertTrue(all(r['installed_on_name'] for r in rows))
        js = json.load(open(os.path.join(self.tmp, 'snow_rows.json')))
        self.assertEqual(set(js[0]), set(ex.SNOW_FIELDS))

    def test_first_seen_persists(self):
        st = json.load(open(os.path.join(self.tmp, 'state.json')))
        later = NOW + dt.timedelta(days=3)
        rows, _ = ex.run(ex.Fleet(self.url, fake_fleet.TOKEN, per_page=50), 7, self.tmp,
                         os.path.join(self.tmp, 'state.json'), now=later)
        self.assertEqual(st, json.load(open(os.path.join(self.tmp, 'state.json'))))
        b = [r for r in rows if r['install_location'] == '/Users/u/Applications/Google Chrome.app'][0]
        self.assertEqual(b['install_date'], '2026-10-20 12:00:00')

    def test_bad_token_fails(self):
        with self.assertRaises(Exception):
            ex.Fleet(self.url, 'wrong').get('/api/v1/fleet/hosts')

    def test_date_parsing(self):
        self.assertEqual(ex.fmt(ex.parse_any_date('20261020')), '2026-10-20 00:00:00')
        self.assertEqual(ex.fmt(ex.parse_any_date('2026-10-20 09:00:00 +0000')), '2026-10-20 09:00:00')
        self.assertIsNone(ex.parse_any_date('0'))
        self.assertIsNone(ex.parse_any_date('garbage'))
        self.assertEqual(ex.parse_candidates('a=0,b=1792491500,c')['b'].year, 2026)


if __name__ == '__main__':
    unittest.main()
