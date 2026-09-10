#!/usr/bin/env python3
"""잘못된 후보와 불완전한 설치 증거의 release PASS를 거부한다."""
import copy
import importlib.util
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location('release_smoke', Path(__file__).with_name('release-install-smoke.py'))
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)
probe = smoke.module('probe_test', 'install-environment-probe.py')


class CandidateTests(unittest.TestCase):
    def setUp(self):
        self.env = {'SOURCE_RUN_ID': '123', 'SOURCE_ARTIFACT_ID': '456', 'SOURCE_SHA': 'a'*40,
                    'DMG_SHA256': 'b'*64, 'EXPECTED_VERSION': '0.2.0', 'EXPECTED_BUILD': '18',
                    'GITHUB_REPOSITORY': 'postmelee/alhangeul-macos'}
        self.candidate = smoke.identity(self.env)
        self.run = {'id': 123, 'head_sha': 'a'*40, 'head_repository': {'full_name': self.env['GITHUB_REPOSITORY']},
                    'repository': {'full_name': self.env['GITHUB_REPOSITORY']},
                    'path': '.github/workflows/release-publish.yml', 'event': 'workflow_dispatch',
                    'status': 'completed', 'conclusion': 'success'}
        self.artifact = {'id': 456, 'workflow_run': {'id': 123, 'head_sha': 'a'*40}, 'expired': False,
                         'name': 'alhangeul-macos-0.2.0-public-dmg', 'size_in_bytes': 100}

    def test_valid_origin(self):
        smoke.validate_origin(self.candidate, self.run, self.artifact)

    def test_input_shell_and_identity_rejected(self):
        for key in self.env:
            for value in ('', '$(whoami)', 'bad\nvalue'):
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    smoke.identity(dict(self.env, **{key: value}))

    def test_origin_mismatch_rejected(self):
        for key, bad in [('id', 124), ('head_sha', 'c'*40), ('path', '.github/workflows/pr-ci.yml'),
                         ('event', 'pull_request'), ('conclusion', 'failure'), ('status', 'in_progress'),
                         ('head_repository', {'full_name': 'other/fork'})]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                smoke.validate_origin(self.candidate, dict(self.run, **{key: bad}), self.artifact)

    def test_artifact_substitution_rejected(self):
        for key, bad in [('id', 457), ('expired', True), ('size_in_bytes', smoke.MAX_ARCHIVE+1),
                         ('name', 'rehearsal'), ('workflow_run', {'id': 124, 'head_sha': 'a'*40})]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                smoke.validate_origin(self.candidate, self.run, dict(self.artifact, **{key: bad}))

    def test_flat_archive(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with zipfile.ZipFile(root/'a.zip', 'w') as z:
                z.writestr('alhangeul-macos-0.2.0.dmg', b'sample')
                z.writestr('alhangeul-macos-0.2.0.dmg.sha256', b'hash')
                z.writestr('release-notes-0.2.0.md', b'notes')
            result = smoke.extract_archive(root/'a.zip', root/'out', '0.2.0')
            self.assertEqual(result.read_bytes(), b'sample')

    def test_archive_escape_symlink_or_extra_app_rejected(self):
        for extra in ('../escape.md', '/escape.md', 'nested/file.md', 'evil.app', 'alhangeul-macos-0.2.0-link.md'):
            with self.subTest(extra=extra), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                with zipfile.ZipFile(root/'a.zip', 'w') as z:
                    z.writestr('alhangeul-macos-0.2.0.dmg', b'sample')
                    info = zipfile.ZipInfo(extra)
                    if 'link' in extra:
                        info.external_attr = (stat.S_IFLNK | 0o777) << 16
                    z.writestr(info, b'target')
                with self.assertRaises(ValueError):
                    smoke.extract_archive(root/'a.zip', root/'out', '0.2.0')
                self.assertFalse((root/'out').exists())

    def states(self):
        first = {'launch_count': 1, 'phase': 'searchable', 'pre_install_environment_verified': True,
                 'before_install_paths': [], 'results': [{'case': c, 'result': 'PASS'} for c in
                 ('automatic-first-install-search', 'body-only-search', 'korean-body-only-search')]}
        stopped = copy.deepcopy(first)
        stopped['results'].append({'case': 'candidate-app-not-running', 'result': 'PASS'})
        final = {'phase': 'cleaned', 'cleanup_index_verified': True, 'assisted_actions': ['lifecycle'],
                 'results': [{'case': c, 'result': 'PASS'} for c in
                 sorted(smoke.LIFECYCLE_REQUIRED | {'cleanup-importer-catalog'})]}
        return first, stopped, final

    def test_complete_evidence(self):
        smoke.require_complete(*self.states())

    def test_relaunch_assistance_missing_search_rejected(self):
        for key, value in [('launch_count', 2), ('assisted_actions', ['developer-register']),
                           ('results', []), ('before_install_paths', ['/old.hwp']),
                           ('pre_install_environment_verified', False)]:
            first, stopped, final = self.states()
            first[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                smoke.require_complete(first, stopped, final)

    def test_stop_cleanup_miss_and_failure_rejected(self):
        for kind in ('stop', 'cleanup', 'failure', 'miss', 'lifecycle'):
            first, stopped, final = self.states()
            if kind == 'stop': stopped['results'].pop()
            if kind == 'cleanup': final['phase'] = 'cleanup-pending-index'
            if kind == 'failure': final['results'].append({'case': 'query-error', 'result': 'FAIL'})
            if kind == 'miss': final['results'].append({'case': 'automatic-discovery', 'result': 'MISS'})
            if kind == 'lifecycle': final['results'].pop(0)
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                smoke.require_complete(first, stopped, final)

    def test_environment_never_qualifies_release(self):
        with patch.object(probe.platform, 'system', return_value='Linux'):
            result = probe.probe(1)
        self.assertEqual(result['status'], 'ENVIRONMENT_UNAVAILABLE')
        self.assertIs(result['release_eligible'], False)

    def test_unknown_folder_state_does_not_replace_txt_probe(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            def fake(args, timeout=30):
                stdout = ''
                if args[0].endswith('mdutil'): stdout = 'unknown indexing state'
                if args[0].endswith('mdfind'): stdout = str(next(root.glob('Documents/*/control.txt'))) + '\n'
                return {'argv': args, 'returncode': 0, 'stdout': stdout, 'stderr': ''}
            with patch.object(probe.platform, 'system', return_value='Darwin'), \
                    patch.object(probe, 'existing_installations', return_value=[]), \
                    patch.object(probe.Path, 'home', return_value=root), patch.object(probe, 'command', side_effect=fake):
                result = probe.probe(1)
            self.assertEqual(result['status'], 'ENVIRONMENT_READY')
            self.assertIs(result['release_eligible'], False)
            self.assertTrue(result['owned_files_removed'])


if __name__ == '__main__':
    unittest.main()
