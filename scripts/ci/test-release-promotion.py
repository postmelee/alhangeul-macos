#!/usr/bin/env python3
"""검증 회차/파일 바꿔치기와 불완전한 결과로 공개하는 회귀를 막는다."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location('promotion', Path(__file__).with_name('release-promotion.py'))
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)
fixtures = p.smoke.module('install_tests', 'test-release-install-smoke.py')


class PromotionTests(unittest.TestCase):
    def setUp(self):
        fixture = fixtures.CandidateTests()
        fixture.setUp()
        self.c = fixture.candidate
        self.run = dict(fixture.run, id=789, path='.github/workflows/release-first-install.yml', run_attempt=2)
        first, stopped, final = fixture.states()
        self.e = {'verify-result.json': {'schema_version': 1, 'status': 'PASS', 'phase': 'verify',
                    'release_eligible': True, 'candidate': self.c, 'harness_sha': self.c['source_sha'],
                    'run_id': '789', 'run_attempt': '2',
                    'environment': {'status': 'ENVIRONMENT_READY', 'architecture': 'arm64'}},
                  'first-launch.json': first, 'stopped-search.json': stopped, 'state.json': final}
        self.a = {'id': 42, 'name': 'first-install-evidence-macos-15-789-2', 'expired': False,
                  'workflow_run': {'id': 789, 'head_sha': self.c['source_sha']}, 'size_in_bytes': 1234}
        name = 'alhangeul-macos-0.2.0.dmg'
        self.release = {'id': 101, 'draft': True, 'prerelease': False, 'tag_name': 'v0.2.0',
                        'assets': [{'id': i, 'name': n, 'state': 'uploaded', 'size': 100}
                                   for i, n in enumerate((name, name + '.sha256'), 1)]}

    def test_both_architectures(self):
        for runner, arch in p.RUNNERS.items():
            self.e['verify-result.json']['environment']['architecture'] = arch
            p.validate_evidence(self.c, self.run, runner, self.e)
        p.validate_run(self.c, self.run, '789')
        p.validate_evidence_artifact(self.c, self.run, self.a, 'macos-15')

    def test_untrusted_run(self):
        for key, value in [('head_sha', 'c'*40), ('path', '.github/workflows/pr-ci.yml'),
                           ('event', 'pull_request'), ('status', 'in_progress'), ('conclusion', 'failure'),
                           ('run_attempt', 0), ('id', 790), ('repository', {'full_name': 'fork/repo'}),
                           ('head_repository', {'full_name': 'fork/repo'})]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                p.validate_run(self.c, dict(self.run, **{key: value}), '789')

    def test_stale_or_foreign_artifact(self):
        for key, value in [('name', 'first-install-evidence-macos-15-789-1'), ('expired', True),
                           ('workflow_run', {'id': 790, 'head_sha': 'a'*40}), ('size_in_bytes', p.MAX_EVIDENCE+1)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                p.validate_evidence_artifact(self.c, self.run, dict(self.a, **{key: value}), 'macos-15')

    def test_result_identity_or_missing_gate(self):
        mutations = [('status', 'ENVIRONMENT_READY'), ('release_eligible', False), ('phase', 'fetch'),
                     ('candidate', dict(self.c, dmg_sha256='c'*64)), ('candidate', dict(self.c, expected_build='17')),
                     ('candidate', dict(self.c, source_artifact_id='999')), ('harness_sha', 'c'*40),
                     ('run_id', '790'), ('run_attempt', '1'),
                     ('environment', {'status': 'ENVIRONMENT_READY', 'architecture': 'x86_64'})]
        for key, value in mutations:
            evidence = copy.deepcopy(self.e)
            evidence['verify-result.json'][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                p.validate_evidence(self.c, self.run, 'macos-15', evidence)

    def test_incomplete_lifecycle_and_manual_assistance(self):
        for filename, key, value in [('state.json', 'cleanup_index_verified', False),
                                      ('state.json', 'results', []),
                                      ('first-launch.json', 'assisted_actions', ['register']),
                                      ('stopped-search.json', 'results', [])]:
            evidence = copy.deepcopy(self.e)
            evidence[filename][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                p.validate_evidence(self.c, self.run, 'macos-15', evidence)

    def test_archive_root_and_traversal(self):
        for bad in (None, '../escape', 'nested/verify-result.json'):
            with self.subTest(bad=bad), tempfile.TemporaryDirectory() as tmp:
                archive = Path(tmp) / 'a.zip'
                with zipfile.ZipFile(archive, 'w') as z:
                    for name, value in self.e.items():
                        if bad == 'nested/verify-result.json' and name == 'verify-result.json':
                            name = bad
                        z.writestr(name, json.dumps(value))
                    if bad == '../escape':
                        z.writestr(bad, 'x')
                if bad:
                    with self.assertRaises(ValueError):
                        p.read_evidence(archive)
                else:
                    self.assertEqual(p.read_evidence(archive), self.e)

    def test_release_asset_and_checksum(self):
        with tempfile.TemporaryDirectory() as tmp:
            dmg = Path(tmp) / 'candidate.dmg'
            checksum = Path(tmp) / 'checksum'
            dmg.write_bytes(b'validated DMG')
            candidate = dict(self.c, dmg_sha256=p.smoke.sha256(dmg))
            checksum.write_text(candidate['dmg_sha256'] + '  alhangeul-macos-0.2.0.dmg\n')
            p.verify_bytes(candidate, dmg, checksum)
            checksum.write_text(candidate['dmg_sha256'] + '  other.dmg\n')
            with self.assertRaises(ValueError):
                p.verify_bytes(candidate, dmg, checksum)
            dmg.write_bytes(b'rebuilt DMG')
            with self.assertRaises(ValueError):
                p.verify_bytes(candidate, dmg, checksum)
        p.release_assets(self.c, self.release)
        for key, value in [('prerelease', True), ('tag_name', 'v0.1.11'), ('assets', []),
                           ('assets', self.release['assets'] * 2)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                p.release_assets(self.c, dict(self.release, **{key: value}))

    def test_retry_same_public_bytes_and_no_downgrade(self):
        public = copy.deepcopy(self.release)
        public['draft'] = False
        public['assets'][0]['download_count'] = 42
        self.assertEqual(p.asset_identity(self.c, self.release), p.asset_identity(self.c, public))
        public['assets'][0]['id'] = 99
        self.assertNotEqual(p.asset_identity(self.c, self.release), p.asset_identity(self.c, public))
        p.check_latest(self.c, {'tag_name': 'v0.1.11'})
        p.check_latest(self.c, {'tag_name': 'v0.2.0'})
        with self.assertRaises(ValueError):
            p.check_latest(self.c, {'tag_name': 'v0.2.1'})

    def test_missing_second_runner_never_passes(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(p, 'api', return_value=self.run), \
                patch.object(p.subprocess, 'check_output', return_value=b'[{"artifacts": []}]'):
            with self.assertRaises(ValueError):
                p.validate_all(self.c, '789', Path(tmp))

    def test_publish_retry_and_last_minute_rerun(self):
        env = {key.upper(): value for key, value in self.c.items() if key != 'repository'}
        env.update(GITHUB_REPOSITORY=self.c['repository'], VALIDATION_RUN_ID='789')
        for mode in ('draft', 'public', 'rerun', 'replacement'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                proof = {'candidate': self.c, 'validation': {'run': self.run, 'artifacts': [self.a]},
                         'release': self.release}
                (root / 'promotion-proof.json').write_text(json.dumps(proof))
                current = copy.deepcopy(self.release)
                if mode == 'public':
                    current['draft'] = False
                if mode == 'replacement':
                    current['assets'][0]['id'] = 999
                published = dict(current, draft=False)
                responses = [dict(self.run, run_attempt=3 if mode == 'rerun' else 2), self.a, published]
                with patch.dict(p.os.environ, env, clear=True), \
                     patch('sys.argv', ['promotion', 'publish', '--output', str(root)]), \
                     patch.object(p, 'api', side_effect=responses), \
                     patch.object(p, 'verify_release', return_value=current), \
                     patch.object(p.subprocess, 'run') as mutation:
                    if mode in ('rerun', 'replacement'):
                        with self.assertRaises(ValueError):
                            p.main()
                        mutation.assert_not_called()
                    else:
                        p.main()
                        self.assertEqual(mutation.call_count, 1 if mode == 'draft' else 0)
                        if mode == 'draft':
                            self.assertEqual(mutation.call_args.args[0][1:3], ['release', 'edit'])
                        self.assertTrue((root / 'published-release.json').exists())

    def test_pages_public_gate_rejects_draft_and_prerelease(self):
        # Execute the actual workflow predicate so authenticated draft visibility cannot regress.
        workflow = Path('.github/workflows/pages-docs-deploy.yml').read_text()
        line = next(line for line in workflow.splitlines() if 'if ! jq -e --arg asset' in line)
        predicate = line.split("'", 2)[1]
        for draft, pre, expected in [(True, False, 1), (False, True, 1), (False, False, 0)]:
            release = dict(self.release, draft=draft, prerelease=pre)
            result = p.subprocess.run(['jq', '-e', '--arg', 'asset', 'alhangeul-macos-0.2.0.dmg', predicate],
                                      input=json.dumps(release), text=True, capture_output=True)
            self.assertEqual(result.returncode, expected)


if __name__ == '__main__':
    unittest.main()
