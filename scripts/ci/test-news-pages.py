#!/usr/bin/env python3
"""외부 API/배포 없이 수집 실패 격리와 실제 Pages 조립·workflow 계약을 검증한다."""
import copy
from datetime import datetime, timedelta, timezone
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / 'scripts/ci/prepare-news-data.py'
spec = importlib.util.spec_from_file_location('prepare_news', HELPER)
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class PagesNewsTests(unittest.TestCase):
    def setUp(self):
        (ROOT / 'build.noindex').mkdir(exist_ok=True)
        self.tmp = tempfile.TemporaryDirectory(prefix='news-pages-test-', dir=ROOT / 'build.noindex')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.now = datetime.now(timezone.utc)
        self.data = {'schema_version': 2, 'updated_at': self.now.isoformat(),
                     'expires_at': (self.now + timedelta(hours=48)).isoformat(),
                     'items': [{'platform': 'threads', 'permalink': 'https://www.threads.com/@postmelee/post/SyntheticOnly'}]}
        self.source = self.root / 'fresh.json'
        self.source.write_text(json.dumps(self.data))
        self.env = {'THREADS_ACCESS_TOKEN': 'synthetic-secret', 'THREADS_EXPECTED_USER_ID': '1234567',
                    'THREADS_TOKEN_EXPIRES_AT': (self.now + timedelta(days=30)).isoformat()}
        self.docs = self.root / 'docs'
        (self.docs / 'updates').mkdir(parents=True)
        (self.docs / 'data').mkdir()
        (self.docs / 'index.html').write_text('home fixture')
        (self.docs / 'updates/index.html').write_text('updates fixture')
        (self.docs / 'data/news.json').write_text(json.dumps(self.data))
        self.appcast = self.root / 'public.xml'
        self.appcast.write_bytes(b'<?xml version="1.0"?>\n<rss version="2.0"><channel><title>public fixture</title></channel></rss>\n')

    def assemble(self, output, *extra):
        return subprocess.run(['bash', str(ROOT / 'scripts/ci/prepare-pages-artifact.sh'),
                               '--docs-dir', str(self.docs), '--appcast', str(self.appcast),
                               '--output-dir', str(output), *map(str, extra)], capture_output=True, text=True)

    def test_switch_rejects_typo_and_disabled_never_contacts_network(self):
        for value in ('', 'false'):
            self.assertFalse(p.enabled(value))
        self.assertTrue(p.enabled('true'))
        for value in ('TRUE', 'yes', '0'):
            with self.assertRaises(p.news.NewsError): p.enabled(value)
        with patch.object(p.news, 'ThreadsClient') as client, patch.object(p.news, 'OEmbedClient') as embed:
            result = p.collect(False, self.source, environment={})
            client.assert_not_called(); embed.assert_not_called()
            self.assertEqual(result['status'], 'disabled')
            self.assertEqual(json.loads(self.source.read_text()), p.SEED)

    def test_missing_credentials_and_expiry_fail_before_clients(self):
        for key in self.env:
            env = dict(self.env); del env[key]
            with patch.object(p.news, 'ThreadsClient') as client, self.assertRaises(p.news.NewsError):
                p.collect(True, self.source, environment=env)
            client.assert_not_called()

    def test_fresh_empty_and_inactive_contract(self):
        self.assertEqual(p.prepare(True, self.source, now=self.now), self.data)
        self.assertEqual(p.prepare(False), p.SEED)
        with self.assertRaises(p.news.NewsError): p.prepare(True)
        with self.assertRaises(p.news.NewsError): p.prepare(False, self.source)
        self.data['items'] = []
        self.source.write_text(json.dumps(self.data))
        self.assertEqual(p.prepare(True, self.source, now=self.now)['items'], [])

    def test_stale_future_expired_and_invalid_are_rejected(self):
        for delta in (-901, 301):
            data = copy.deepcopy(self.data)
            data['updated_at'] = (self.now + timedelta(seconds=delta)).isoformat()
            data['expires_at'] = (self.now + timedelta(hours=1)).isoformat()
            self.source.write_text(json.dumps(data))
            with self.assertRaises(p.news.NewsError): p.prepare(True, self.source, now=self.now)
        for data in (dict(self.data, expires_at=(self.now - timedelta(seconds=1)).isoformat()),
                     dict(self.data, html='forbidden'), p.SEED):
            self.source.write_text(json.dumps(data))
            with self.assertRaises(p.news.NewsError): p.prepare(True, self.source, now=self.now)

    def test_actual_assembler_preserves_appcast_and_same_snapshot_in_both_paths(self):
        outputs = [self.root / name for name in ('docs-only', 'release')]
        for output in outputs:
            result = self.assemble(output, '--news-enabled', 'true', '--news-data', self.source)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((output / 'appcast.xml').read_bytes(), self.appcast.read_bytes())
            self.assertEqual(json.loads((output / 'data/news.json').read_text()), self.data)
        self.assertEqual((outputs[0] / 'data/news.json').read_bytes(), (outputs[1] / 'data/news.json').read_bytes())

    def test_disabled_assembly_replaces_repository_snapshot_with_seed(self):
        output = self.root / 'disabled'
        result = self.assemble(output)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((output / 'data/news.json').read_text()), p.SEED)
        self.assertEqual(json.loads((self.docs / 'data/news.json').read_text()), self.data)

    def test_failed_assembly_keeps_previous_directory_bytes(self):
        output = self.root / 'existing'
        output.mkdir(); (output / 'sentinel').write_bytes(b'previous public artifact')
        for args in (['--news-enabled', 'true'], ['--news-enabled', 'true', '--news-data', self.root/'missing.json'],
                     ['--news-enabled', 'typo'], ['--news-data', self.source]):
            result = self.assemble(output, *args)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(list(output.iterdir()), [output / 'sentinel'])
            self.assertEqual((output / 'sentinel').read_bytes(), b'previous public artifact')
        for data in (dict(self.data, updated_at=(self.now - timedelta(minutes=16)).isoformat(),
                          expires_at=(self.now + timedelta(hours=1)).isoformat()),
                     dict(self.data, expires_at=self.data['updated_at']), dict(self.data, html='forbidden')):
            self.source.write_text(json.dumps(data))
            result = self.assemble(output, '--news-enabled', 'true', '--news-data', self.source)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(list(output.iterdir()), [output / 'sentinel'])
        self.assertFalse(list(self.root.glob('.pages-artifact.*')))

    def test_collection_api_embed_failure_and_fresh_retry(self):
        fixture = p.news.read_json(ROOT / 'scripts/ci/fixtures/threads-news/probe-responses.json')
        class Client:
            def __init__(self, fail=False): self.pages = iter(copy.deepcopy(fixture['pages'])); self.fail = fail
            def get(self, endpoint, params):
                if endpoint == 'me': return fixture['profile']
                if self.fail: raise p.news.NewsError('synthetic API error')
                return next(self.pages)
        for kind in ('api', 'embed'):
            previous = self.source.read_bytes()
            with patch.object(p.news, 'ThreadsClient', return_value=Client(kind == 'api')), \
                 patch.object(p.news, 'OEmbedClient') as embed:
                embed.return_value.check.side_effect = p.news.NewsError('synthetic oEmbed error')
                with self.assertRaises(p.news.NewsError): p.collect(True, self.source, environment=self.env)
            self.assertEqual(self.source.read_bytes(), previous)
        with patch.object(p.news, 'ThreadsClient', side_effect=lambda *a, **kw: Client()) as client, \
             patch.object(p.news, 'OEmbedClient') as embed:
            embed.return_value.check.side_effect = lambda url: {'platform': 'threads', 'permalink': url}
            p.collect(True, self.source, environment=self.env)
            first = json.loads(self.source.read_text())
            fixture['pages'][0]['data'][0]['topic_tag'] = '다른 태그'
            p.collect(True, self.source, environment=self.env)
            second = json.loads(self.source.read_text())
            self.assertEqual(client.call_count, 2)
            self.assertEqual(len(first['items']), 1)
            self.assertEqual(second['items'], [])
            self.assertNotIn(self.env['THREADS_ACCESS_TOKEN'], self.source.read_text())

    def test_cli_no_secret_echo_and_no_prior_snapshot_collect(self):
        for args in (['collect', '--input', str(self.source)], ['collect', '--enabled', 'true']):
            env = dict(os.environ, THREADS_ACCESS_TOKEN='synthetic-secret', THREADS_EXPECTED_USER_ID='', THREADS_NEWS_ENABLED='false')
            result = subprocess.run([sys.executable, str(HELPER), *args, '--output', str(self.source)], env=env,
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('synthetic-secret', result.stdout + result.stderr)
            self.assertNotIn('Traceback', result.stderr)


class WorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflows = {}
        for name in ('pages-docs-deploy', 'release-promote', 'threads-news-sync'):
            path = ROOT / f'.github/workflows/{name}.yml'
            raw = subprocess.check_output(['ruby', '-rjson', '-rpsych', '-e', 'puts JSON.generate(Psych.safe_load(File.read(ARGV[0]), permitted_classes: [], aliases: false))', str(path)])
            cls.workflows[name] = json.loads(raw)

    def test_shared_lock_and_schedule_caller_do_not_deadlock(self):
        for name in ('pages-docs-deploy', 'release-promote'):
            self.assertEqual(self.workflows[name]['concurrency'], {'group': 'pages-deploy', 'cancel-in-progress': False})
        sync = self.workflows['threads-news-sync']
        self.assertNotEqual(sync['concurrency']['group'], 'pages-deploy')
        caller = sync['jobs']['refresh-pages']
        self.assertIn("github.event_name == 'schedule'", caller['if'])
        self.assertIn("vars.THREADS_NEWS_ENABLED == 'true'", caller['if'])
        self.assertIn("github.ref == 'refs/heads/main'", caller['if'])
        self.assertEqual(caller['uses'], './.github/workflows/pages-docs-deploy.yml')
        self.assertEqual(caller['permissions']['pages'], 'write')
        self.assertEqual(caller['permissions']['id-token'], 'write')

    def test_secret_only_collection_and_one_day_pages_artifact(self):
        for name in ('pages-docs-deploy', 'release-promote'):
            for job in self.workflows[name]['jobs'].values():
                self.assertNotIn('THREADS_ACCESS_TOKEN', job.get('env', {}))
                for step in job.get('steps', []):
                    if 'THREADS_ACCESS_TOKEN' in step.get('env', {}):
                        self.assertIn('prepare-news-data.py collect', step['run'])
                    if step.get('uses', '').startswith('actions/upload-pages-artifact@'):
                        self.assertEqual(step['with']['retention-days'], 1)
        proof = next(s for s in self.workflows['release-promote']['jobs']['promote']['steps'] if s.get('name') == 'Preserve promotion proof')
        self.assertIn('!build.noindex/promotion/pages/**', proof['with']['path'])
        self.assertNotIn('RUNNER_TEMP', proof['with']['path'])
        self.assertEqual(proof['with']['retention-days'], 30)

    def test_fail_closed_dependencies_and_release_order(self):
        for workflow, job_id in [('pages-docs-deploy', 'prepare-pages-artifact'), ('release-promote', 'promote')]:
            jobs = self.workflows[workflow]['jobs']; steps = jobs[job_id]['steps']
            collect = next(i for i,s in enumerate(steps) if 'prepare-news-data.py collect' in s.get('run', ''))
            assemble = next(i for i,s in enumerate(steps) if 'prepare-pages-artifact.sh' in s.get('run', ''))
            upload = next(i for i,s in enumerate(steps) if s.get('uses', '').startswith('actions/upload-pages-artifact@'))
            self.assertLess(collect, assemble); self.assertLess(assemble, upload)
            self.assertEqual(jobs['deploy-pages']['needs'], job_id)
            for step in (steps[collect], steps[assemble], steps[upload]):
                self.assertFalse(step.get('continue-on-error', False))
                self.assertNotIn('always()', step.get('if', ''))
            if workflow == 'release-promote':
                publish = next(i for i,s in enumerate(steps) if 'release-promotion.py publish' in s.get('run', ''))
                self.assertLess(upload, publish)


if __name__ == '__main__':
    unittest.main()
