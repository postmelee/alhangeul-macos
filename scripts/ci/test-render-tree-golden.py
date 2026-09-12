#!/usr/bin/env python3
"""Rust/Swift build 없이 golden orchestration의 실패 경계를 검사한다."""
import contextlib
import copy
import importlib.util
import io
from pathlib import Path
import tempfile
import sys
import os
import subprocess
import shutil
import shlex

sys.dont_write_bytecode = True
import unittest

SPEC = importlib.util.spec_from_file_location("golden", Path(__file__).with_name("render-tree-golden.py"))
golden = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(golden)


class GoldenTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="golden-fixture-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "RustBridge").mkdir()
        (self.root / golden.SAMPLE).parent.mkdir(parents=True)
        (self.root / golden.SAMPLE).write_bytes(b"fixed sample")
        self.write("rhwp-core.lock", 'lock_version = 2\nrhwp_repo = "https://github.com/edwardkim/rhwp.git"\nrhwp_ref_kind = "release-tag"\nrhwp_release_tag = "v1.2.3"\nrhwp_commit = "' + "a" * 40 + '"\nrhwp_enabled_features = "native-skia"\n')
        self.write("RustBridge/Cargo.toml", '[dependencies]\nrhwp = { git = "https://github.com/edwardkim/rhwp.git", tag = "v1.2.3", features = ["native-skia"] }\n')
        self.write("RustBridge/Cargo.lock", '[[package]]\nname = "rhwp"\nsource = "git+https://github.com/edwardkim/rhwp.git?tag=v1.2.3#' + "a" * 40 + '"\n')
        self.path = self.root / golden.GOLDEN
        self.tree = {"marker": 18446744073709551615, "children": [{"x": 2, "y": 1}], "text": "고정 fixture"}
        self.run_mode("update")
        self.before = self.path.read_bytes()

    def write(self, path, value):
        (self.root / path).write_text(value)

    def replace(self, path, old, new):
        self.write(path, (self.root / path).read_text().replace(old, new))

    def run_mode(self, mode, **kwargs):
        with contextlib.redirect_stdout(io.StringIO()):
            golden.run_contract(mode, self.root, self.path,
                                producer=kwargs.get("producer", lambda _: copy.deepcopy(self.tree)),
                                consumer=kwargs.get("consumer", lambda *_: None))

    def assert_failure_unchanged(self, pattern, mode="verify", **kwargs):
        with self.assertRaisesRegex(golden.ContractError, pattern):
            self.run_mode(mode, **kwargs)
        self.assertEqual(self.before, self.path.read_bytes())

    def test_repeat_writer_is_identical(self):
        self.run_mode("update")
        self.assertEqual(self.before, self.path.read_bytes())
        self.run_mode("verify")
        self.assertEqual(self.before, self.path.read_bytes())

    def test_canonical_preserves_unsigned_and_array_order(self):
        decoded = golden.read_json(golden.canonical(self.tree))
        self.assertEqual(decoded["marker"], 2**64 - 1)
        self.assertEqual(golden.canonical({"b": 2, "a": 1}), golden.canonical({"a": 1, "b": 2}))
        self.assertNotEqual(golden.canonical([1, 2]), golden.canonical([2, 1]))

    def test_duplicate_json_is_rejected(self):
        with self.assertRaisesRegex(golden.ContractError, "duplicate"):
            golden.read_json(b'{"tree":1,"tree":2}')

    def test_source_mismatch_blocks(self):
        self.replace("RustBridge/Cargo.lock", "a" * 40, "b" * 40)
        self.assert_failure_unchanged("source/Cargo")

    def test_feature_mismatch_blocks(self):
        self.replace("RustBridge/Cargo.toml", "native-skia", "other")
        self.assert_failure_unchanged("features/Cargo")

    def test_stale_pin_blocks_before_producer(self):
        for path in ("rhwp-core.lock", "RustBridge/Cargo.lock"):
            self.replace(path, "a" * 40, "b" * 40)
        self.assert_failure_unchanged("stale golden provenance", producer=lambda _: self.fail("producer ran before stale identity check"))

    def test_stale_sample_blocks(self):
        (self.root / golden.SAMPLE).write_bytes(b"changed sample")
        self.assert_failure_unchanged("stale golden provenance")

    def test_stale_output_blocks_without_rewrite(self):
        self.tree["marker"] = 123
        self.assert_failure_unchanged("stale golden producer output")

    def test_corrupt_tree_hash_blocks(self):
        content = golden.read_json(self.before)
        content["tree"]["marker"] = 1
        self.path.write_bytes(golden.canonical(content))
        self.before = self.path.read_bytes()
        self.assert_failure_unchanged("stale golden tree hash")

    def test_missing_golden_is_not_created_by_verifier(self):
        self.path.unlink()
        with self.assertRaisesRegex(golden.ContractError, "missing golden"):
            self.run_mode("verify")
        self.assertFalse(self.path.exists())

    def test_writer_failure_preserves_previous_golden(self):
        def reject(*_):
            raise golden.ContractError("known payload decode failure")
        self.assert_failure_unchanged("known payload", mode="update", consumer=reject)

    def test_verifier_consumes_actual_producer(self):
        seen = []
        self.run_mode("verify", consumer=lambda _, trees: seen.extend(trees))
        self.assertEqual(seen, [self.tree, self.tree])

    def test_explicit_writer_accepts_reviewed_change(self):
        self.tree["marker"] = 123
        self.run_mode("update")
        self.assertNotEqual(self.before, self.path.read_bytes())
        self.run_mode("verify")

    def test_commit_pin_supported(self):
        self.replace("rhwp-core.lock", 'rhwp_ref_kind = "release-tag"', 'rhwp_ref_kind = "commit"')
        self.replace("RustBridge/Cargo.toml", 'tag = "v1.2.3"', 'rev = "' + "a" * 40 + '"')
        self.replace("RustBridge/Cargo.lock", "tag=v1.2.3", "rev=" + "a" * 40)
        self.run_mode("update")
        self.run_mode("verify")

    def test_golden_paths_enable_macos_contract_without_pixel_smoke(self):
        env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull)
        # Test the stdout interface, without writing into the enclosing Actions job's files.
        env.pop("GITHUB_STEP_SUMMARY", None)
        env.pop("GITHUB_OUTPUT", None)
        def git(*args):
            return subprocess.check_output(["git", *args], cwd=self.root, env=env, stderr=subprocess.DEVNULL, text=True).strip()
        git("init", "-q")
        git("config", "user.name", "Fixture")
        git("config", "user.email", "fixture@example.invalid")
        git("add", ".")
        git("commit", "-qm", "base")
        helper = Path(__file__).with_name("classify-pr-changes.sh").resolve()
        for path in [golden.GOLDEN.as_posix(), "scripts/update-render-tree-golden.sh",
                     "scripts/verify-render-tree-golden.sh", "scripts/ci/render-tree-golden.py",
                     "scripts/ci/render_tree_golden_check.swift", "scripts/ci/test-render-tree-golden.py",
                     "RustBridge/examples/render_tree_golden.rs"]:
            with self.subTest(path=path):
                base = git("rev-parse", "HEAD")
                target = self.root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("classification fixture\n")
                git("add", path)
                git("commit", "-qm", "change")
                output = subprocess.check_output(["bash", str(helper), base, "HEAD"], cwd=self.root, env=env, text=True)
                self.assertIn("| run_macos_build | `true` |", output)
                self.assertIn("| run_render_smoke | `false` |", output)
                if path == "RustBridge/examples/render_tree_golden.rs":
                    self.assertEqual(sum(line.startswith("- " + path + " affects") for line in output.splitlines()), 1)

    def test_nonfinite_number_rejected(self):
        with self.assertRaises(ValueError):
            golden.canonical({"value": float("nan")})


class PythonPreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="golden-python-preflight-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.bin / "dirname").symlink_to(shutil.which("dirname"))
        self.scripts = self.root / "scripts"
        self.scripts.mkdir()
        for name in ["verify-render-tree-golden.sh", "update-render-tree-golden.sh", "release.sh", "package-release.sh"]:
            shutil.copy2(golden.ROOT / "scripts" / name, self.scripts / name)
        self.env = dict(os.environ, PATH=str(self.bin), ALHANGEUL_BUILD_ROOT=str(self.root / "build.noindex"))

    def python_version(self, minor):
        # Execute the actual version-check expression with only the interpreter version varied.
        command = f'import sys; sys.version_info=(3,{minor}); exec(sys.argv[1])'
        path = self.bin / "python3"
        path.write_text(f'#!/bin/sh\nexec {shlex.quote(sys.executable)} -c {shlex.quote(command)} "$2"\n')
        path.chmod(0o755)

    def run_script(self, name, *args):
        return subprocess.run(["/bin/bash", str(self.scripts / name), *args], env=self.env, capture_output=True, text=True)

    def test_missing_python_has_actionable_error(self):
        result = self.run_script("verify-render-tree-golden.sh", "--check-environment")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("python3 was not found in PATH", result.stderr)

    def test_python_310_rejected(self):
        self.python_version(10)
        result = self.run_script("verify-render-tree-golden.sh", "--check-environment")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires Python 3.11 or later", result.stderr)

    def test_python_311_accepted_without_build_tools(self):
        self.python_version(11)
        result = self.run_script("verify-render-tree-golden.sh", "--check-environment")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("prerequisite satisfied", result.stdout)

    def test_preflight_rejects_extra_arguments(self):
        self.python_version(11)
        result = self.run_script("verify-render-tree-golden.sh", "--check-environment", "unexpected")
        self.assertEqual(result.returncode, 2)

    def test_release_and_package_fail_before_artifact_cleanup(self):
        self.python_version(10)
        staging = self.root / "build.noindex/release/staging/keep"
        staging.parent.mkdir(parents=True)
        staging.write_text("previous artifact")
        for name in ["release.sh", "package-release.sh", "update-render-tree-golden.sh"]:
            with self.subTest(script=name):
                result = self.run_script(name, "0.1.11")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("requires Python 3.11 or later", result.stderr)
                self.assertEqual(staging.read_text(), "previous artifact")


if __name__ == "__main__":
    unittest.main()
