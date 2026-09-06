#!/usr/bin/env python3
"""Rust/Swift build 없이 golden orchestration의 실패 경계를 검사한다."""
import contextlib
import copy
import importlib.util
import io
from pathlib import Path
import tempfile
import sys

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

    def test_nonfinite_number_rejected(self):
        with self.assertRaises(ValueError):
            golden.canonical({"value": float("nan")})


if __name__ == "__main__":
    unittest.main()
