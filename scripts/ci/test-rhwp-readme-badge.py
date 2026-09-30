#!/usr/bin/env python3
"""실제 CLI로 다음 pin 동기화·provenance 분리·stale 실패를 검증한다."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "scripts/ci/update-rhwp-readme-badge.py"
COMMIT = "a" * 40


class BadgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest = self.root / "Sources/HostApp/Resources/rhwp-studio/manifest.json"
        self.manifest.parent.mkdir(parents=True)
        self.readme = self.root / "README.md"
        self.readme.write_text('기존 배지\n  <!-- bundled-rhwp-badges:start -->\n  <!-- bundled-rhwp-badges:end -->\n기존 릴리스 안내\n')
        self.pin()

    def pin(self, core_tag="v0.8.6", studio_tag="v0.8.6", core_kind="release-tag", studio_kind="release-tag", studio_commit=COMMIT):
        (self.root / "rhwp-core.lock").write_text(
            f'rhwp_repo = "https://github.com/edwardkim/rhwp.git"\nrhwp_ref_kind = "{core_kind}"\n'
            f'rhwp_release_tag = "{core_tag}"\nrhwp_commit = "{COMMIT}"\n')
        self.manifest.write_text(json.dumps({
            "source_repository": "https://github.com/edwardkim/rhwp.git", "source_ref_kind": studio_kind,
            "source_release_tag": studio_tag, "source_resolved_commit": studio_commit}))

    def run_cli(self, *args, success=True):
        result = subprocess.run([sys.executable, str(HELPER), "--root", str(self.root), *args], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0 if success else 1, result.stderr)
        return self.readme.read_text()

    def test_current_and_next_sync_update_version_and_link_together(self):
        self.run_cli("--check", success=False)
        current = self.run_cli()
        self.assertIn('bundled%20rhwp-v0.8.6-blue', current)
        self.assertIn('/releases/tag/v0.8.6', current)
        self.pin(core_tag="v9.8.7", studio_tag="v9.8.7")
        self.run_cli("--check", success=False)
        next_readme = self.run_cli()
        self.assertIn('bundled%20rhwp-v9.8.7-blue', next_readme)
        self.assertIn('/releases/tag/v9.8.7', next_readme)
        self.assertNotIn('v0.8.6', next_readme)
        self.assertTrue(next_readme.startswith('기존 배지\n'))
        self.assertTrue(next_readme.endswith('기존 릴리스 안내\n'))
        self.assertEqual(next_readme, self.run_cli())
        self.assertEqual(next_readme, self.run_cli("--check"))

    def test_different_versions_have_separate_labels_and_links(self):
        self.pin(studio_tag="v0.9.0", studio_commit="b" * 40)
        result = self.run_cli()
        self.assertIn('bundled%20rhwp%20native-v0.8.6', result)
        self.assertIn('bundled%20rhwp%20Studio-v0.9.0', result)
        self.assertIn('/releases/tag/v0.8.6', result)
        self.assertIn('/releases/tag/v0.9.0', result)

    def test_equal_tags_different_commits_remain_separate(self):
        self.pin(studio_commit="b" * 40)
        result = self.run_cli()
        self.assertIn('bundled rhwp native: v0.8.6', result)
        self.assertIn('bundled rhwp Studio: v0.8.6', result)
        self.assertIn('b' * 40, result)

    def test_commit_pin_does_not_claim_release_tag(self):
        self.pin(core_kind="commit", studio_kind="commit")
        result = self.run_cli()
        self.assertIn(f'/commit/{COMMIT}', result)
        self.assertIn(f'bundled%20rhwp-{COMMIT[:12]}', result)
        self.assertNotIn('v0.8.6', result)

    def test_release_and_commit_pin_are_separate(self):
        self.pin(studio_kind="commit")
        result = self.run_cli()
        self.assertIn('/releases/tag/v0.8.6', result)
        self.assertIn(f'/commit/{COMMIT}', result)

    def test_prerelease_shields_hyphen_escape(self):
        self.pin(core_tag="v0.9.0-rc.1", studio_tag="v0.9.0-rc.1")
        result = self.run_cli()
        self.assertIn('v0.9.0--rc.1-blue', result)
        self.assertIn('/releases/tag/v0.9.0-rc.1', result)

    def test_stale_link_check_does_not_write(self):
        current = self.run_cli().replace('/releases/tag/v0.8.6', '/releases/latest')
        self.readme.write_text(current)
        self.assertEqual(current, self.run_cli('--check', success=False))

    def test_invalid_provenance_fails_without_writing(self):
        before = self.readme.read_text()
        for changes in ({"core_kind": "branch"}, {"core_tag": "main"}, {"studio_commit": "bad"}):
            with self.subTest(changes=changes):
                self.pin(**changes)
                self.assertEqual(before, self.run_cli(success=False))

    def test_missing_or_duplicate_markers_fail(self):
        for value in ('기존 문서\n', self.readme.read_text() * 2):
            self.readme.write_text(value)
            self.assertEqual(value, self.run_cli(success=False))

    def test_workflow_updates_after_sync_and_stages_readme(self):
        workflow = (ROOT / '.github/workflows/rhwp-upstream-sync-pr.yml').read_text()
        sync = workflow.index('          scripts/sync-rhwp-studio.sh \\\n')
        update = workflow.index('          python3 scripts/ci/update-rhwp-readme-badge.py\n')
        stage = workflow.index('          git add \\\n')
        self.assertLess(sync, update)
        self.assertLess(update, stage)
        self.assertIn('            README.md \\\n', workflow[stage:])


if __name__ == '__main__':
    unittest.main()
