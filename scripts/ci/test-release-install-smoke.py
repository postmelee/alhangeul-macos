#!/usr/bin/env python3
"""잘못된 후보와 불완전한 설치 증거의 release PASS를 거부한다."""
import copy
import importlib.util
import json
from pathlib import Path
import plistlib
import stat
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
import zipfile

spec = importlib.util.spec_from_file_location('release_smoke', Path(__file__).with_name('release-install-smoke.py'))
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)
probe = smoke.module('probe_test', 'install-environment-probe.py')


class CandidateTests(unittest.TestCase):
    def test_primary_cleanup_and_detach_failures_are_preserved(self):
        for primary in (None, ValueError('reinstall baseline failed')):
            with self.subTest(primary=primary), tempfile.TemporaryDirectory() as tmp:
                path = Path(tmp) / 'state.json'
                path.write_text('{}')
                def cleanup(state):
                    state['phase'] = 'cleanup-pending-index'
                    raise RuntimeError('catalog stale')
                def detach(*args):
                    raise RuntimeError('detach failed')
                system = SimpleNamespace(cleanup=cleanup, save=lambda p, s: p.write_text(json.dumps(s)))
                result = {}
                if primary is None:
                    with self.assertRaisesRegex(RuntimeError, 'catalog stale'):
                        smoke.finish_trial(system, path, True, Path(tmp), detach, result, primary)
                else:
                    smoke.finish_trial(system, path, True, Path(tmp), detach, result, primary)
                    self.assertEqual(result['verification_error'], str(primary))
                self.assertEqual(result['cleanup_error'], 'catalog stale')
                self.assertEqual(result['detach_error'], 'detach failed')
                self.assertEqual(result['status'], 'HARNESS_ERROR')
                self.assertEqual(json.loads(path.read_text())['phase'], 'cleanup-pending-index')

    def receipt_fixture(self, home, name, identifier='com.postmelee.alhangeul', importer='/candidate.app/importer'):
        root = home / 'Library/Containers' / name
        root.mkdir(parents=True)
        (root / '.com.apple.containermanagerd.metadata.plist').write_bytes(
            plistlib.dumps({'MCMMetadataIdentifier': identifier}))
        path = root / 'Data/Library/Preferences/com.postmelee.alhangeul.plist'
        path.parent.mkdir(parents=True)
        path.write_bytes(plistlib.dumps({'alhangeul.spotlight.reimport.requestedInstallation':
                                        {'importerPath': importer, 'installationIdentifier': 'old'},
                                        'unrelated-private-preference': 'must-not-copy'}))
        return path

    def test_receipt_uuid_container_alias_and_no_preference_mutation(self):
        system = smoke.module('receipt_system', 'spotlight-system-smoke.py')
        with tempfile.TemporaryDirectory() as tmp, patch.object(smoke.Path, 'home', return_value=Path(tmp)):
            home = Path(tmp)
            app = '/candidate.app'
            path = self.receipt_fixture(home, 'container-uuid', importer=app + '/' + system.PLUGIN)
            before = path.read_bytes()
            (home / 'Library/Containers/com.postmelee.alhangeul').symlink_to(path.parents[3], target_is_directory=True)
            found, receipt = smoke.candidate_receipt(system, {'install_app': app}, timeout=0)
            self.assertEqual(found, path.resolve())
            self.assertEqual(set(receipt), {'importerPath', 'installationIdentifier'})
            self.assertEqual(path.read_bytes(), before)

    def test_missing_foreign_and_ambiguous_receipts_rejected(self):
        system = smoke.module('receipt_reject_system', 'spotlight-system-smoke.py')
        for kind in ('missing', 'foreign-container', 'foreign-app', 'duplicate'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as tmp, \
                    patch.object(smoke.Path, 'home', return_value=Path(tmp)):
                home = Path(tmp)
                if kind != 'missing':
                    self.receipt_fixture(home, 'uuid-one',
                                         identifier='other.app' if kind == 'foreign-container' else 'com.postmelee.alhangeul',
                                         importer='/other.app' if kind == 'foreign-app' else '/candidate.app/' + system.PLUGIN)
                if kind == 'duplicate':
                    self.receipt_fixture(home, 'uuid-two', importer='/candidate.app/' + system.PLUGIN)
                with self.assertRaises(ValueError):
                    smoke.candidate_receipt(system, {'install_app': '/candidate.app'}, timeout=0)

    def test_trial_order_snapshots_and_failed_state_preserved(self):
        for fail in (False, True):
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as tmp:
                output = Path(tmp)
                calls = []
                state = {'launch_count': 0}
                def operation(name):
                    def execute(current, *args):
                        calls.append(name)
                        current['last_operation'] = name
                        if name in ('launch', 'reinstall_app'):
                            current['launch_count'] += 1
                        if fail and name == 'reinstall_app':
                            raise ValueError('copy failure')
                    return execute
                names = ('environment', 'install', 'launch', 'automatic_search', 'stop_candidate',
                         'prepare_reinstall', 'reinstall_app', 'reinstall_search', 'lifecycle')
                system = SimpleNamespace(**{name: operation(name) for name in names},
                                         save=lambda path, value: path.write_text(json.dumps(value)))
                with patch.object(smoke, 'candidate_receipt', return_value=(output / 'private.plist', {'request': 'old'})):
                    if fail:
                        with self.assertRaisesRegex(ValueError, 'copy failure'):
                            smoke.installation_trials(system, state, output / 'state.json', output)
                        self.assertNotIn('lifecycle', calls)
                        self.assertEqual(json.loads((output / 'state.json').read_text())['last_operation'], 'reinstall_app')
                    else:
                        smoke.installation_trials(system, state, output / 'state.json', output)
                        self.assertEqual(calls, ['environment', 'install', 'launch', 'automatic_search',
                                                'stop_candidate', 'automatic_search', 'prepare_reinstall',
                                                'reinstall_app', 'reinstall_search', 'stop_candidate',
                                                'reinstall_search', 'lifecycle'])
                        self.assertEqual(json.loads((output / 'reinstall-stopped-search.json').read_text())['launch_count'], 2)
                        self.assertEqual(state['assisted_actions'], ['lifecycle'])
                    self.assertEqual(json.loads((output / 'first-launch.json').read_text())['launch_count'], 1)
                    self.assertEqual(json.loads((output / 'stopped-search.json').read_text())['initial_receipt'], {'request': 'old'})

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
        first = {'id': 'owned-test', 'automatic': True, 'install_app': '/candidate.app', 'files': '/owned/Files',
                 'source_app_hashes': {'app': 'hash'}, 'source_importer_hashes': {'importer': 'hash'},
                 'installed_bundle_dates_ns': {'app': 1, 'importer': 1}, 'installed_object': [1, 2, 3],
                 'prepared_corpus': {'document-a.hwp': [1, 2, 'hash']},
                 'launch_count': 1, 'phase': 'searchable', 'pre_install_environment_verified': True,
                 'before_install_paths': [], 'results': [{'case': c, 'result': 'PASS'} for c in
                 ('automatic-first-install-search', 'body-only-search', 'korean-body-only-search')]}
        stopped = copy.deepcopy(first)
        stopped['results'].append({'case': 'candidate-app-not-running', 'result': 'PASS'})
        stopped['initial_receipt'] = {'importerPath': '/candidate.app/Contents/Library/Spotlight/Alhangeul.mdimporter',
                                      'buildIdentifier': '0.2.1-19', 'modificationDate': 'same',
                                      'installationIdentifier': 'old-object'}
        reinstalled = copy.deepcopy(stopped)
        reinstalled.update(launch_count=2, installed_object=[1, 4, 5])
        reinstalled['reinstall'] = {'phase': 'searchable', 'before_receipt': stopped['initial_receipt'],
                                   'after_receipt': dict(stopped['initial_receipt'], installationIdentifier='new-object'),
                                   'before_object': first['installed_object'], 'after_object': [1, 4, 5],
                                   'prepared_corpus': first['prepared_corpus'], 'search_outcome': 'recovered'}
        baseline = {'mode': 'absent', 'english_paths': [], 'korean_paths': [],
                    'control_paths': ['/owned/Files/index-control.txt'],
                    'stable_seconds': 4, 'elapsed_seconds': 4, 'timeout_seconds': 60}
        reinstalled['reinstall'].update(before_copy_search=copy.deepcopy(baseline),
                                        before_launch_search=copy.deepcopy(baseline))
        reinstalled['results'].extend({'case': c, 'result': 'PASS'} for c in
                                     ('reinstall-old-body-removed', 'reinstall-old-korean-removed',
                                      'before-reinstall-search-state', 'same-version-reinstall-prepared',
                                      'before-reinstall-launch-search-state',
                                      'same-version-reinstall-launched', 'body-only-search',
                                      'korean-body-only-search', 'metadata-document-a.hwp',
                                      'metadata-document-b.hwpx', 'metadata-document-c.hwp',
                                      'automatic-same-version-reinstall-search'))
        for row in reinstalled['results']:
            if row['case'] in ('before-reinstall-search-state', 'before-reinstall-launch-search-state'):
                row.update(copy.deepcopy(baseline))
            if row['case'] == 'automatic-same-version-reinstall-search':
                row['search_outcome'] = 'recovered'
        restopped = copy.deepcopy(reinstalled)
        restopped['results'].extend({'case': c, 'result': 'PASS'} for c in
                                   ('candidate-app-not-running', 'body-only-search', 'korean-body-only-search',
                                    'metadata-document-a.hwp', 'metadata-document-b.hwpx', 'metadata-document-c.hwp',
                                    'automatic-same-version-reinstall-search'))
        restopped['results'][-1]['search_outcome'] = 'recovered'
        final = copy.deepcopy(restopped)
        final.update(phase='cleaned', cleanup_index_verified=True, assisted_actions=['lifecycle'])
        final['results'].extend({'case': c, 'result': 'PASS'} for c in
                               sorted(smoke.LIFECYCLE_REQUIRED | {'cleanup-importer-catalog'}))
        return tuple(copy.deepcopy(state) for state in (first, stopped, final, reinstalled, restopped))

    def test_complete_evidence(self):
        smoke.require_complete(*self.states())

    def test_retained_search_is_accepted_only_as_maintained(self):
        states = self.states()
        baseline = {'mode': 'searchable', 'english_paths': ['/owned/Files/' + name for name in
                     ('document-a.hwp', 'document-b.hwpx', 'document-c.hwp')],
                    'korean_paths': ['/owned/Files/document-a.hwp', '/owned/Files/document-b.hwpx'],
                    'control_paths': ['/owned/Files/index-control.txt'],
                    'stable_seconds': 4, 'elapsed_seconds': 6, 'timeout_seconds': 60}
        for state in (states[3], states[4], states[2]):
            state['reinstall'].update(before_copy_search=copy.deepcopy(baseline),
                                      before_launch_search=copy.deepcopy(baseline), search_outcome='maintained')
            for row in state['results']:
                if row['case'] in ('before-reinstall-search-state', 'before-reinstall-launch-search-state'):
                    row.update(baseline)
                if row['case'] == 'automatic-same-version-reinstall-search':
                    row['search_outcome'] = 'maintained'
        smoke.require_complete(*states)
        for state in (states[3], states[4], states[2]):
            state['reinstall']['search_outcome'] = 'recovered'
        with self.assertRaisesRegex(ValueError, '분류'):
            smoke.require_complete(*states)

    def test_incomplete_or_fabricated_baseline_rejected(self):
        for field, value in [('control_paths', []), ('english_paths', ['/owned/Files/document-a.hwp']),
                             ('stable_seconds', 0), ('elapsed_seconds', 601), ('mode', 'partial')]:
            states = self.states()
            for state in (states[3], states[4], states[2]):
                state['reinstall']['before_launch_search'][field] = value
                for row in state['results']:
                    if row['case'] == 'before-reinstall-launch-search-state':
                        row[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                smoke.require_complete(*states)

    def test_first_install_only_is_not_release_eligible(self):
        with self.assertRaisesRegex(ValueError, 'snapshot'):
            smoke.require_complete(*self.states()[:3])

    def test_invalid_reinstall_evidence_rejected(self):
        mutations = [
            (3, ('launch_count',), 3),
            (3, ('assisted_actions',), ['diagnostic-register']),
            (3, ('source_app_hashes',), {'other': 'candidate'}),
            (3, ('reinstall', 'before_receipt', 'installationIdentifier'), 'reset-record'),
            (3, ('reinstall', 'after_receipt', 'installationIdentifier'), 'old-object'),
            (3, ('reinstall', 'after_receipt', 'buildIdentifier'), 'different-version'),
            (3, ('reinstall', 'after_receipt', 'modificationDate'), 'touched'),
            (3, ('reinstall', 'after_object'), [1, 2, 3]),
            (3, ('reinstall', 'prepared_corpus'), {'edited': [1, 2, 'other']}),
            (4, ('launch_count',), 3),
            (4, ('installed_object',), [1, 9, 9]),
            (2, ('reinstall', 'before_receipt'), {}),
        ]
        for index, keys, value in mutations:
            states = self.states()
            target = states[index]
            for key in keys[:-1]:
                target = target[key]
            target[keys[-1]] = value
            with self.subTest(index=index, keys=keys), self.assertRaises(ValueError):
                smoke.require_complete(*states)

    def test_first_stop_cannot_replace_reinstall_stop(self):
        states = list(self.states())
        states[4] = copy.deepcopy(states[3])
        states[2]['results'] = states[4]['results'] + [
            {'case': c, 'result': 'PASS'} for c in sorted(smoke.LIFECYCLE_REQUIRED | {'cleanup-importer-catalog'})]
        with self.assertRaisesRegex(ValueError, '종료 후 검색'):
            smoke.require_complete(*states)

    def test_missing_pre_reinstall_baseline_rejected_even_with_later_pass(self):
        states = self.states()
        for state in (states[3], states[4], states[2]):
            state['results'] = [r for r in state['results'] if r['case'] != 'before-reinstall-search-state']
        with self.assertRaisesRegex(ValueError, '사전 상태'):
            smoke.require_complete(*states)

    def test_original_search_cannot_replace_reinstall_search(self):
        states = self.states()
        for state in (states[3], states[4], states[2]):
            start = len(states[1]['results'])
            state['results'] = state['results'][:start] + [
                r for r in state['results'][start:] if r['case'] != 'body-only-search']
        with self.assertRaisesRegex(ValueError, '실행 이후 본문 검색'):
            smoke.require_complete(*states)

    def test_reinstall_receipt_cannot_change_after_search(self):
        states = self.states()
        states[4]['reinstall']['after_receipt']['installationIdentifier'] = 'third-installation'
        with self.assertRaisesRegex(ValueError, '검색 이후'):
            smoke.require_complete(*states)

    def test_relaunch_assistance_missing_search_rejected(self):
        for key, value in [('launch_count', 2), ('assisted_actions', ['developer-register']),
                           ('results', []), ('before_install_paths', ['/old.hwp']),
                           ('pre_install_environment_verified', False)]:
            first, stopped, final, reinstalled, restopped = self.states()
            first[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                smoke.require_complete(first, stopped, final, reinstalled, restopped)

    def test_stop_cleanup_miss_and_failure_rejected(self):
        for kind in ('stop', 'cleanup', 'failure', 'miss', 'lifecycle'):
            first, stopped, final, reinstalled, restopped = self.states()
            if kind == 'stop': stopped['results'].pop()
            if kind == 'cleanup': final['phase'] = 'cleanup-pending-index'
            if kind == 'failure': final['results'].append({'case': 'query-error', 'result': 'FAIL'})
            if kind == 'miss': final['results'].append({'case': 'automatic-discovery', 'result': 'MISS'})
            if kind == 'lifecycle': final['results'].pop(0)
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                smoke.require_complete(first, stopped, final, reinstalled, restopped)

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
