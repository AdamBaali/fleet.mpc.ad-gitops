import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import compare  # noqa: E402

HDR = 'test_id\thost\tos\tapp\tkey\tversion\tmethod\tevent\tutc\texpected_publisher\tnote\n'


def sw(name, path, install, src, last='', pub='', cands=None, version='1.0'):
    return {'display_name': name, 'version': version, 'install_location': path, 'install_date': install,
            'install_date_source': src, 'last_used': last, 'publisher': pub, 'publisher_source': 'x',
            'candidates': cands or {}}


class CompareTest(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.d, 'export', 'hosts'))

    def export(self, host, software):
        json.dump({'host': {'id': 1, 'name': host, 'hostname': host, 'serial': 'S1'}, 'software': software},
                  open(os.path.join(self.d, 'export', 'hosts', '1.json'), 'w'))

    def gt(self, lines):
        p = os.path.join(self.d, 'gt.tsv')
        with open(p, 'w') as f:
            f.write(HDR + ''.join('\t'.join(l) + '\n' for l in lines))
        return p

    def run_cmp(self, lines):
        return compare.evaluate(compare.load_gt([self.gt(lines)]), compare.load_export(os.path.join(self.d, 'export')))

    def test_install_within_two_minutes_passes(self):
        self.export('mac', [sw('VLC', '/Applications/VLC.app', '2026-10-20 09:01:30', 'native:spotlight_date_added',
                                pub='VideoLAN', cands={'native:spotlight_date_added': '2026-10-20 09:01:30', 'native:bundle_created': '2026-09-01 00:00:00'})])
        v = self.run_cmp([['M-1', 'mac', 'macos', 'VLC', '/Applications/VLC.app', '3.0.21', 'dmg', 'install', '2026-10-20T09:00:00Z', 'VideoLAN', '']])
        self.assertEqual([x['result'] for x in v], ['PASS', 'PASS'])
        self.assertIn('native:spotlight_date_added', v[0]['detail'])
        self.assertNotIn('bundle_created', v[0]['detail'].split('matching:')[1])

    def test_install_three_minutes_off_fails(self):
        self.export('mac', [sw('VLC', '/Applications/VLC.app', '2026-10-20 09:03:01', 's')])
        v = self.run_cmp([['M-1', 'mac', 'macos', 'VLC', '/Applications/VLC.app', '', 'dmg', 'install', '2026-10-20T09:00:00Z', '', '']])
        self.assertEqual(v[0]['result'], 'FAIL')

    def test_day_precision_source_same_day_passes(self):
        self.export('win', [sw('VLC media player', '', '2026-10-20 00:00:00', 'native:registry_install_date', version='3.0.21')])
        v = self.run_cmp([['W-1', 'win', 'windows', 'VLC', 'VLC media player', '3.0', 'msi', 'install', '2026-10-20T22:30:00Z', '', '']])
        self.assertEqual(v[0]['result'], 'PASS')

    def test_open_checks_last_used(self):
        self.export('mac', [sw('VLC', '/Applications/VLC.app', '', '', last='2026-10-20 09:10:40')])
        v = self.run_cmp([['M-3', 'mac', 'macos', 'VLC', '/Applications/VLC.app', '', '', 'open', '2026-10-20T09:10:00Z', '', '']])
        self.assertEqual(v[0]['result'], 'PASS')

    def test_upgrade_keeps_or_moves(self):
        lines = [['M-1', 'mac', 'macos', 'R', '/Applications/R.app', '', 'dmg', 'install', '2026-10-20T09:00:00Z', '', ''],
                 ['M-2', 'mac', 'macos', 'R', '/Applications/R.app', '', 'dmg', 'upgrade', '2026-10-20T13:00:00Z', '', '']]
        self.export('mac', [sw('R', '/Applications/R.app', '2026-10-20 09:00:30', 's')])
        self.assertEqual(self.run_cmp(lines)[1]['result'], 'PASS')
        self.export('mac', [sw('R', '/Applications/R.app', '2026-10-20 13:00:30', 's')])
        self.assertEqual(self.run_cmp(lines)[1]['result'], 'PARTIAL')

    def test_uninstall_requires_row_gone(self):
        lines = [['U-1', 'mac', 'macos', 'R', '/Applications/R.app', '', '', 'uninstall', '2026-10-20T14:00:00Z', '', '']]
        self.export('mac', [])
        self.assertEqual(self.run_cmp(lines)[0]['result'], 'PASS')
        self.export('mac', [sw('R', '/Applications/R.app', '', '')])
        self.assertEqual(self.run_cmp(lines)[0]['result'], 'FAIL')

    def test_unsigned_expects_empty_publisher(self):
        self.export('mac', [sw('U', '/Applications/U.app', '2026-10-20 09:00:00', 's', pub='')])
        v = self.run_cmp([['M-4', 'mac', 'macos', 'U', '/Applications/U.app', '', 'build', 'install', '2026-10-20T09:00:00Z', '-', '']])
        self.assertEqual(v[1]['result'], 'PASS')

    def test_missing_host_is_blocked(self):
        self.export('mac', [])
        v = self.run_cmp([['L-1', 'fedora', 'linux', 'hello', 'hello', '', 'dnf', 'install', '2026-10-20T09:00:00Z', '', '']])
        self.assertEqual(v[0]['result'], 'BLOCKED')

    def test_write_outputs(self):
        self.export('mac', [])
        v = self.run_cmp([['U-1', 'mac', 'macos', 'R', '/Applications/R.app', '', '', 'uninstall', '2026-10-20T14:00:00Z', '', '']])
        compare.write(v, os.path.join(self.d, 'out'))
        self.assertTrue(open(os.path.join(self.d, 'out', 'verdicts.md')).read().startswith('| test_id'))


if __name__ == '__main__':
    unittest.main()
