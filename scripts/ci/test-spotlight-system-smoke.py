#!/usr/bin/env python3
"""운영 smoke의 경로 소유권, 환경 대조, 반복 추출 판정 회귀 검사."""
import importlib.util
import json
import subprocess
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("smoke", Path(__file__).with_name("spotlight-system-smoke.py"))
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


class SmokeTests(unittest.TestCase):
    def test_command_failure_without_log_retains_diagnostic(self):
        with self.assertRaisesRegex(RuntimeError, "synthetic failure detail") as caught:
            smoke.run([sys.executable, "-c", "import sys; print('synthetic failure detail', file=sys.stderr); sys.exit(7)"])
        self.assertIn("command failed (7)", str(caught.exception))
        self.assertNotIn("see None", str(caught.exception))

    def test_failure_excerpt_is_bounded_but_log_is_complete(self):
        output = "start\n" + "x" * 4000 + "\nlast diagnostic"
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "failure.txt"
            result = subprocess.CompletedProcess(["synthetic"], 1, output, "")
            with patch.object(smoke.subprocess, "run", return_value=result):
                with self.assertRaisesRegex(RuntimeError, "last diagnostic") as caught:
                    smoke.run(["synthetic"], log)
            self.assertEqual(log.read_text(), output)
            self.assertLess(len(str(caught.exception)), 2300)

    def test_timeout_keeps_partial_bytes_and_log(self):
        error = subprocess.TimeoutExpired(["synthetic"], 30, output=b"partial output\n", stderr=b"partial error")
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "timeout.txt"
            with patch.object(smoke.subprocess, "run", side_effect=error):
                with self.assertRaisesRegex(RuntimeError, "timed out after 30s") as caught:
                    smoke.run(["synthetic"], log)
            self.assertIn("partial error", str(caught.exception))
            self.assertEqual(log.read_text(), "partial output\npartial error")

    def test_absent_providers_are_valid_but_service_errors_fail(self):
        empty = subprocess.CompletedProcess(["pluginkit"], 0, "  (no matches)\n", "")
        with patch.object(smoke.subprocess, "run", return_value=empty):
            self.assertEqual(smoke.providers(), {identifier: [] for identifier in smoke.IDS})
        unavailable = subprocess.CompletedProcess(["pluginkit"], 1, "", "service unavailable")
        with patch.object(smoke.subprocess, "run", return_value=unavailable):
            with self.assertRaisesRegex(RuntimeError, "service unavailable"):
                smoke.providers()

    def test_korean_query_filters_scope_and_normalizes_data_alias(self):
        state = {"files": "/Users/test/Documents/Owned/Files"}
        document = state["files"] + "/document.hwp"
        with patch.object(smoke, "run", return_value="/unrelated/document.hwp\n" + document + "\n/System/Volumes/Data" + document) as command:
            self.assertEqual(smoke.query(state, "은빛나비검색"), [document])
            self.assertEqual(command.call_args.args[0][2], "/Users/test/Documents")
            self.assertIn("은빛나비검색", command.call_args.args[0][3])
        for token in ["", 'word" OR true', "*", "a\\b"]:
            with self.assertRaises(ValueError): smoke.query(state, token)

    def test_empty_results_require_live_control_and_stable_absence(self):
        state = {"files": "/synthetic/Files", "results": []}
        now = [0]
        def sleep(seconds): now[0] += seconds
        with patch.object(smoke.time, "monotonic", side_effect=lambda: now[0]), \
             patch.object(smoke.time, "sleep", side_effect=sleep):
            with patch.object(smoke, "query", return_value=[]):
                with self.assertRaises(RuntimeError):
                    smoke.expect_paths(state, "OldWord", [], "service-unavailable", timeout=4)
            self.assertEqual(state["results"][-1]["result"], "FAIL")
            self.assertFalse(state["results"][-1]["control_ok"])
            now[0] = 0
            responses = iter([[], ["/synthetic/Files/index-control.txt"],
                              ["/synthetic/Files/document.hwp"], ["/synthetic/Files/index-control.txt"],
                              [], ["/synthetic/Files/index-control.txt"],
                              [], ["/synthetic/Files/index-control.txt"],
                              [], ["/synthetic/Files/index-control.txt"]])
            with patch.object(smoke, "query", side_effect=lambda *args: next(responses)):
                smoke.expect_paths(state, "OldWord", [], "settled-deletion", timeout=10)
            self.assertEqual(now[0], 8)
            self.assertEqual(state["results"][-1]["result"], "PASS")

    def test_cleanup_refuses_unowned_or_symlinked_locations(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            key = "1234abcd"
            state = {"id": key}
            for name, parent in [("workspace", "Documents"), ("install_root", "Applications")]:
                owned = home / parent / ("AlhangeulSpotlightSmoke-" + key)
                owned.mkdir(parents=True)
                (owned / ".spotlight-smoke-owner").write_text(key)
                state[name] = str(owned)
            state["files"] = str(Path(state["workspace"]) / "Files")
            state["install_app"] = str(Path(state["install_root"]) / "Alhangeul.app")
            with patch.object(smoke.Path, "home", return_value=home):
                smoke.owned_locations(state)
                marker = Path(state["workspace"]) / ".spotlight-smoke-owner"
                marker.write_text("someone-else")
                with self.assertRaises(ValueError): smoke.owned_locations(state)
                marker.write_text(key)
                Path(state["files"]).symlink_to(home)
                with self.assertRaises(ValueError): smoke.owned_locations(state)
                Path(state["files"]).unlink()
                Path(state["install_app"]).symlink_to(home)
                with self.assertRaises(ValueError): smoke.owned_locations(state)
                Path(state["install_app"]).unlink()
                state["workspace"] = str(home / "Documents")
                with self.assertRaises(ValueError): smoke.owned_locations(state)

    def test_txt_environment_failure_cannot_pass_body_search(self):
        state = {"files": "/synthetic/Files", "evidence": "/synthetic/evidence", "token": "BodyToken", "results": []}
        with patch.object(smoke, "run", return_value=""), patch.object(smoke, "expect_paths", side_effect=RuntimeError("timeout")) as expect:
            with self.assertRaisesRegex(RuntimeError, "environment unavailable"):
                smoke.index(state)
            self.assertEqual(state["index_environment"], "unavailable")
            self.assertEqual(expect.call_count, 1)
            self.assertEqual(expect.call_args.args[1:3], (smoke.CONTROL, ["index-control.txt"]))

    def test_repeated_metadata_output_and_wrong_importer(self):
        with tempfile.TemporaryDirectory() as directory:
            state = {"evidence": directory, "install_app": "/synthetic/Alhangeul.app"}
            output = Path(directory) / "sample-metadata.plist"
            def command(args, *unused, **kwargs):
                if args[0] == "mdimport":
                    self.assertFalse(output.exists(), "mdimport appends; old output must be removed")
                    output.write_text("synthetic OpenStep dictionary")
                    return str(Path(state["install_app"]) / smoke.PLUGIN)
                return json.dumps({"kMDItemTextContent": "body"})
            with patch.object(smoke, "run", side_effect=command):
                for _ in range(2):
                    self.assertEqual(smoke.metadata_test(state, Path("sample.hwp"), "sample")["kMDItemTextContent"], "body")
            with patch.object(smoke, "run", return_value="with no plugIn"):
                with self.assertRaisesRegex(RuntimeError, "actual importer path"):
                    smoke.metadata_test(state, Path("sample.hwp"), "sample")

    def test_filename_or_kind_cannot_satisfy_body_extraction(self):
        state = {"files": "/synthetic", "evidence": "/synthetic", "token": "BodyToken", "results": []}
        with patch.object(smoke, "metadata_test", return_value={"kMDItemTitle": "BodyToken"}):
            with self.assertRaisesRegex(RuntimeError, "text missing"):
                smoke.verify(state)

    def test_stale_catalog_does_not_report_full_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = {"install_app": str(root / "install/Alhangeul.app"), "install_root": str(root / "install"),
                     "workspace": str(root / "corpus"), "files": str(root / "corpus/Files"),
                     "evidence": directory, "original_apps": {}, "providers_before": {}, "results": []}
            Path(state["install_root"]).mkdir()
            Path(state["workspace"]).mkdir()
            now = [0]
            def sleep(seconds): now[0] += seconds
            def command(args, *unused, **kwargs):
                return str(Path(state["install_app"]) / smoke.PLUGIN) if args[0] == "mdimport" else ""
            with patch.object(smoke, "run", side_effect=command), patch.object(smoke, "providers", return_value={}), \
                 patch.object(smoke.time, "monotonic", side_effect=lambda: now[0]), patch.object(smoke.time, "sleep", side_effect=sleep):
                with self.assertRaisesRegex(RuntimeError, "catalog is stale"):
                    smoke.cleanup(state)
            self.assertEqual(state["phase"], "cleanup-pending-index")
            self.assertFalse(Path(state["install_root"]).exists())
            self.assertFalse(Path(state["workspace"]).exists())
            self.assertEqual(state["results"][-1]["result"], "MISS")

    def test_index_cleanup_failure_still_removes_files_without_claiming_success(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = {"install_app": str(root / "install/Alhangeul.app"), "install_root": str(root / "install"),
                     "workspace": str(root / "corpus"), "files": str(root / "corpus/Files"),
                     "evidence": directory, "original_apps": {}, "providers_before": {}, "results": [],
                     "index_environment": "available", "token": "OldWord", "replacement": "NewWord"}
            Path(state["install_root"]).mkdir()
            files = Path(state["files"])
            files.mkdir(parents=True)
            (files / "index-control.txt").write_text(smoke.CONTROL)
            (files / "document.hwp").write_bytes(b"synthetic")
            def fail(*args):
                self.assertTrue((files / "index-control.txt").exists())
                self.assertFalse((files / "document.hwp").exists())
                raise RuntimeError("stale indexed path")
            with patch.object(smoke, "run", return_value=""), patch.object(smoke, "providers", return_value={}), \
                 patch.object(smoke, "expect_paths", side_effect=fail):
                with self.assertRaisesRegex(RuntimeError, "new smoke run"):
                    smoke.cleanup(state)
            self.assertFalse(Path(state["workspace"]).exists())
            self.assertFalse(Path(state["install_root"]).exists())
            self.assertEqual(state["phase"], "cleanup-pending-index")
            self.assertIn("cleanup-original-apps-providers", [item["case"] for item in state["results"]])
            self.assertFalse(state.get("cleanup_index_verified", False))


if __name__ == "__main__":
    unittest.main()
