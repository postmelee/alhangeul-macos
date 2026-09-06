#!/usr/bin/env python3
"""격리 Git 이력으로 transport/content gate의 통과·차단과 무변경 계약을 검증한다."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

HELPER = Path(__file__).with_name("check-main-devel-content.sh").resolve()


class ContentGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="main-devel-content-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull)
        self.env.pop("GITHUB_STEP_SUMMARY", None)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.commit_file("base.txt", "base\n")
        self.git("branch", "devel")

    def git(self, *args, check=True, cwd=None):
        result = subprocess.run(["git", *args], cwd=cwd or self.root, env=self.env, capture_output=True, text=True)
        if check:
            self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def commit_file(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content if isinstance(content, bytes) else content.encode())
        self.git("add", name)
        self.git("commit", "-qm", "fixture")
        return self.git("rev-parse", "HEAD")

    def gate(self, code, phrase, *, root=None, refs=("main", "devel")):
        cwd = root or self.root
        before = [self.git(*args, cwd=cwd) for args in [("rev-parse", "HEAD"), ("status", "--porcelain"), ("write-tree",)]]
        result = subprocess.run([str(HELPER), *refs], cwd=cwd, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, code, result.stdout + result.stderr)
        self.assertIn(phrase, result.stdout)
        after = [self.git(*args, cwd=cwd) for args in [("rev-parse", "HEAD"), ("status", "--porcelain"), ("write-tree",)]]
        self.assertEqual(before, after, "gate changed HEAD/worktree/index")
        return result.stdout

    def transport(self):
        self.git("switch", "-q", "devel")
        self.commit_file("feature.txt", "feature\n")
        self.git("switch", "-q", "main")
        self.git("merge", "--no-ff", "-m", "release transport", "devel")

    def test_transport_passes(self):
        self.transport()
        self.gate(0, "transport-only history")

    def test_devel_only_work_passes(self):
        self.git("switch", "-q", "devel")
        self.commit_file("feature.txt", "feature\n")
        self.gate(0, "already incorporated")

    def test_main_nonmerge_blocks(self):
        self.commit_file("hotfix.txt", "fix\n")
        self.gate(1, "content absent from source")

    def test_merge_time_content_blocks(self):
        self.git("switch", "-q", "devel")
        self.commit_file("feature.txt", "feature\n")
        self.git("switch", "-q", "main")
        self.git("merge", "--no-ff", "--no-commit", "devel")
        self.commit_file("during-merge.txt", "extra\n")
        self.gate(1, "merge differs from source parent")

    def test_backmerge_passes(self):
        self.commit_file("hotfix.txt", "fix\n")
        self.git("switch", "-q", "devel")
        self.commit_file("feature.txt", "feature\n")
        self.git("merge", "--no-ff", "-m", "backmerge", "main")
        self.gate(0, "already incorporated")

    def test_cherry_pick_equivalent_passes(self):
        fix = self.commit_file("hotfix.txt", "fix\n")
        self.git("switch", "-q", "devel")
        self.commit_file("feature.txt", "feature\n")
        self.git("cherry-pick", fix)
        self.assertNotEqual(fix, self.git("rev-parse", "HEAD"))
        self.gate(0, "equivalent/net content")

    def test_net_zero_main_change_passes(self):
        change = self.commit_file("hotfix.txt", "fix\n")
        self.git("revert", "--no-edit", change)
        self.gate(0, "equivalent/net content")

    def test_conflict_blocks(self):
        self.commit_file("base.txt", "main fix\n")
        self.git("switch", "-q", "devel")
        self.commit_file("base.txt", "different\n")
        self.gate(1, "content conflicts")

    def test_missing_ref_errors(self):
        self.gate(2, "missing or invalid ref", refs=("missing", "devel"))

    def test_shallow_clone_errors(self):
        self.transport()
        shallow = Path(self.temp.name) / "shallow"
        self.git("clone", "-q", "--depth=1", "--no-single-branch", self.root.as_uri(), str(shallow))
        self.gate(2, "shallow history", root=shallow, refs=("origin/main", "origin/devel"))

    def test_unrelated_history_errors(self):
        self.git("switch", "--orphan", "unrelated")
        self.commit_file("unrelated.txt", "new root\n")
        self.gate(2, "no common ancestry", refs=("main", "unrelated"))

    def test_dirty_index_and_worktree_preserved(self):
        self.transport()
        (self.root / "staged.txt").write_text("staged\n")
        self.git("add", "staged.txt")
        (self.root / "base.txt").write_text("dirty\n")
        (self.root / "untracked.txt").write_text("untracked\n")
        self.gate(0, "PASS")
        self.assertEqual((self.root / "base.txt").read_text(), "dirty\n")
        self.assertEqual((self.root / "staged.txt").read_text(), "staged\n")
        self.assertEqual((self.root / "untracked.txt").read_text(), "untracked\n")

    def test_custom_driver_cannot_hide_content(self):
        self.commit_file(".gitattributes", "base.txt merge=discard-main\n")
        self.git("switch", "-q", "devel")
        self.git("merge", "--ff-only", "main")
        self.git("config", "merge.discard-main.driver", "true")
        self.commit_file("base.txt", "devel content\n")
        self.git("switch", "-q", "main")
        self.commit_file("base.txt", "main fix\n")
        self.gate(1, "content conflicts")
        self.assertEqual(self.git("config", "merge.discard-main.driver"), "true")

    def test_binary_content_blocks(self):
        self.commit_file("image.bin", b"\x00\x01main")
        self.gate(1, "content absent")

    def test_ci_must_inspect_source_head_instead_of_merge_checkout(self):
        self.commit_file("hotfix.txt", "main fix\n")
        self.git("switch", "-q", "devel")
        self.commit_file("feature.txt", "feature\n")
        source_head = self.git("rev-parse", "HEAD")
        self.git("switch", "-qc", "synthetic-pr-merge")
        self.git("merge", "--no-ff", "-m", "CI merge checkout", "main")
        self.gate(0, "already incorporated", refs=("main", "HEAD"))
        self.gate(1, "content absent", refs=("main", source_head))

    def test_actions_summary_environment(self):
        summary = Path(self.temp.name) / "actions-summary.md"
        self.env["GITHUB_STEP_SUMMARY"] = str(summary)
        report = self.gate(0, "PASS")
        self.assertEqual(summary.read_text(), report + "\n")

    def test_summary_records_failure(self):
        self.commit_file("hotfix.txt", "fix\n")
        summary = Path(self.temp.name) / "summary.md"
        result = subprocess.run([str(HELPER), "main", "devel", "--summary-file", str(summary)], cwd=self.root, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(summary.read_text(), result.stdout + "\n")


if __name__ == "__main__":
    unittest.main()
