"""Smoke test for run-api-tests.sh against the fake Fleet API. Checks each action writes evidence
with one result line, and that the verdicts follow the fixture data."""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fake_fleet  # noqa: E402

SCRIPT = os.path.join(os.path.dirname(HERE), 'run-api-tests.sh')


@unittest.skipUnless(shutil.which('jq') and shutil.which('curl') and shutil.which('bash'), 'needs jq, curl and bash')
class ApiTestsSmoke(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.srv, cls.url = fake_fleet.start()
        cls.ev = tempfile.mkdtemp()
        env = dict(os.environ, FLEET_URL=cls.url, FLEET_API_TOKEN=fake_fleet.TOKEN, EV=cls.ev,
                   ITAM_STATE=os.path.join(cls.ev, 'first_seen.json'))
        env.pop('SECRETS_ENV', None)
        cls.proc = subprocess.run(['bash', SCRIPT, 'all', '7'], env=env, capture_output=True, text=True, timeout=120)
        cls.tsv = {}
        p = os.path.join(cls.ev, 'results.tsv')
        if os.path.exists(p):
            for line in open(p):
                parts = line.rstrip('\n').split('\t')
                cls.tsv[parts[0]] = parts[1]

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()
        cls.srv.server_close()

    def test_runs_clean(self):
        self.assertEqual(self.proc.returncode, 0, self.proc.stderr[-2000:])

    def test_every_test_has_a_verdict(self):
        for t in ('S-1', 'H-1', 'H-2', 'H-3', 'H-4', 'H-5', 'H-6', 'A-2', 'A-1'):
            self.assertIn(t, self.tsv, t)

    def test_verdicts_follow_fixtures(self):
        self.assertEqual(self.tsv['S-1'], 'PASS')
        self.assertEqual(self.tsv['H-1'], 'PASS')
        self.assertEqual(self.tsv['H-3'], 'PARTIAL')   # Windows VM has no serial
        self.assertEqual(self.tsv['H-5'], 'PARTIAL')   # only the Mac has an IdP user
        self.assertFalse(any(t.startswith(('X-', 'C-')) for t in self.tsv))  # no extension tests
        self.assertEqual(self.tsv['A-2'], 'PASS')
        self.assertEqual(self.tsv['A-1'], 'PASS')

    def test_token_never_written(self):
        for root, _, files in os.walk(self.ev):
            for f in files:
                with open(os.path.join(root, f), errors='ignore') as fh:
                    self.assertNotIn(fake_fleet.TOKEN, fh.read(), f)


if __name__ == '__main__':
    unittest.main()
