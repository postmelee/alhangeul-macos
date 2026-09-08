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
    def test_corpus_changed_during_search_cannot_pass_automatic_observation(self):
        original = {"sample.hwp": [10, 123, "sha256"]}
        state = {"automatic": True, "launch_count": 1, "before_install_paths": [],
                 "prepared_corpus": original, "results": []}
        with patch.object(smoke, "corpus_snapshot", side_effect=[original, {"sample.hwp": [10, 456, "sha256"]}]), \
             patch.object(smoke, "assert_automatic_candidate_unchanged"), \
             patch.object(smoke, "discover", return_value=True), \
             patch.object(smoke, "index"), patch.object(smoke, "verify"):
            with self.assertRaisesRegex(ValueError, "changed during"):
                smoke.automatic_search(state)
        self.assertEqual(state["results"], [])

    def test_unrecorded_bundle_touch_or_replacement_cannot_pass_automatic_search(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / "Candidate.app"
            plugin = app / smoke.PLUGIN
            for bundle in [app, plugin]:
                (bundle / "Contents/MacOS").mkdir(parents=True)
                (bundle / "Contents/Info.plist").write_text("synthetic info")
                (bundle / "Contents/MacOS/Alhangeul").write_bytes(b"synthetic executable")
            state = {"install_app": str(app), "source_app_hashes": smoke.fingerprint(app),
                     "source_importer_hashes": smoke.fingerprint(plugin),
                     "installed_bundle_dates_ns": {"app": app.stat().st_mtime_ns,
                                                   "importer": plugin.stat().st_mtime_ns}}
            smoke.assert_automatic_candidate_unchanged(state)
            original = plugin.stat().st_mtime_ns
            smoke.os.utime(plugin, ns=(original, original + 1_000_000_000))
            with self.assertRaisesRegex(ValueError, "unchanged installed"):
                smoke.assert_automatic_candidate_unchanged(state)
            smoke.os.utime(plugin, ns=(original, original))
            (plugin / "Contents/MacOS/Alhangeul").write_bytes(b"different executable")
            with self.assertRaisesRegex(ValueError, "unchanged installed"):
                smoke.assert_automatic_candidate_unchanged(state)
            with self.assertRaisesRegex(ValueError, "installation provenance"):
                smoke.assert_automatic_candidate_unchanged({})

    def test_phase_failure_is_saved_for_evidence_and_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            path.write_text(json.dumps({"phase": "installed", "results": []}))
            with patch.object(sys, "argv", ["smoke", "verify", "--state", str(path)]), \
                 patch.object(smoke, "owned_locations"), \
                 patch.object(smoke, "verify", side_effect=RuntimeError("synthetic missing importer")):
                with self.assertRaisesRegex(RuntimeError, "missing importer"):
                    smoke.main()
            saved = json.loads(path.read_text())
            self.assertEqual(saved["phase"], "installed")
            self.assertEqual(saved["results"][-1]["case"], "verify-failed")
            self.assertEqual(saved["results"][-1]["result"], "FAIL")
            self.assertIn("missing importer", saved["results"][-1]["reason"])

    def test_automatic_install_requires_pre_install_control(self):
        with patch.object(smoke, "run") as command:
            with self.assertRaisesRegex(ValueError, "environment before"):
                smoke.install({"automatic": True})
            command.assert_not_called()

    def test_registration_comparison_marks_run_assisted_without_touch_or_launch(self):
        state = {"phase": "installed", "install_app": "/synthetic/app", "results": []}
        with patch.object(smoke, "run") as command, patch.object(smoke.os, "utime") as touch:
            smoke.diagnostic_register(state)
        command.assert_called_once_with([smoke.LSREGISTER, "-f", "/synthetic/app"])
        touch.assert_not_called()
        self.assertEqual(state["assisted_actions"], ["diagnostic-register"])
        state["launch_count"] = 1
        with self.assertRaises(ValueError): smoke.diagnostic_register(state)

    def test_automatic_install_does_not_register_or_reindex(self):
        with tempfile.TemporaryDirectory() as directory:
            state = {"id": "test", "automatic": True, "pre_install_environment_verified": True,
                     "install_root": directory + "/install",
                     "source_app": "/source/Alhangeul.app", "install_app": directory + "/install/Alhangeul.app"}
            def copy(args, **kwargs):
                if args[0] == "ditto":
                    (Path(args[2]) / smoke.PLUGIN).mkdir(parents=True)
                return ""
            with patch.object(smoke, "run", side_effect=copy) as command, \
                 patch.object(smoke, "discover", return_value=False):
                smoke.install(state)
            self.assertEqual([call.args[0][0] for call in command.call_args_list], ["ditto", "codesign"])

    def test_direct_copy_does_not_precreate_app_and_tracks_partial_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / "Owned.app"
            state = {"automatic": True, "pre_install_environment_verified": True,
                     "install_layout": "direct", "install_root": str(app), "install_app": str(app),
                     "source_app": "/source/Alhangeul.app"}
            def failed_copy(args, **kwargs):
                self.assertEqual(args[0], "ditto")
                self.assertFalse(app.exists(), "precreated app changes ditto mtime semantics")
                app.mkdir()
                raise RuntimeError("partial copy")
            with patch.object(smoke, "run", side_effect=failed_copy):
                with self.assertRaisesRegex(RuntimeError, "partial copy"):
                    smoke.install(state)
            self.assertEqual(state["install_identity"], [app.stat().st_dev, app.stat().st_ino])

    def test_automatic_index_uses_existing_index_without_mdimport_i(self):
        state = {"automatic": True, "files": "/synthetic/Files", "evidence": "/synthetic",
                 "token": "BodyToken", "results": []}
        with patch.object(smoke, "run") as command, patch.object(smoke, "expect_paths"):
            smoke.index(state)
        command.assert_not_called()
        self.assertEqual(state["phase"], "searchable")

    def test_automatic_search_rejects_assisted_or_relaunched_runs(self):
        valid = {"automatic": True, "launch_count": 1, "before_install_paths": [], "results": [],
                 "prepared_corpus": {"sample.hwp": [10, 123, "sha256"]}}
        for change in [{"automatic": False}, {"assisted_actions": ["replace-app"]},
                       {"launch_count": 2}, {"before_install_paths": ["old.hwp"]}]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                smoke.automatic_search(dict(valid, **change))
        with patch.object(smoke, "corpus_snapshot", return_value=valid["prepared_corpus"]), \
             patch.object(smoke, "assert_automatic_candidate_unchanged"), \
             patch.object(smoke, "discover", return_value=False), \
             patch.object(smoke, "index") as indexing:
            with self.assertRaisesRegex(RuntimeError, "discovery failed"):
                smoke.automatic_search(valid)
            indexing.assert_not_called()
        with patch.object(smoke, "corpus_snapshot", return_value={"new.hwp": []}):
            with self.assertRaisesRegex(ValueError, "unchanged pre-install corpus"):
                smoke.automatic_search(valid)

    def test_direct_app_cleanup_requires_exact_path_and_directory_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            workspace = home / "Documents/AlhangeulSpotlightSmoke-abc123"
            app = home / "Applications/AlhangeulSpotlightSmoke-abc123.app"
            workspace.mkdir(parents=True)
            app.mkdir(parents=True)
            (workspace / ".spotlight-smoke-owner").write_text("abc123")
            state = {"id": "abc123", "workspace": str(workspace), "files": str(workspace / "Files"),
                     "install_layout": "direct", "install_root": str(app), "install_app": str(app),
                     "install_identity": [app.stat().st_dev, app.stat().st_ino]}
            with patch.object(smoke.Path, "home", return_value=home):
                smoke.owned_locations(state)
                state["install_identity"][1] += 1
                with self.assertRaisesRegex(ValueError, "identity mismatch"):
                    smoke.owned_locations(state)
                state["install_root"] = str(home / "Applications/Alhangeul.app")
                with self.assertRaisesRegex(ValueError, "exact owned test location"):
                    smoke.owned_locations(state)

    def test_automatic_search_requires_real_index_before_metadata_diagnostics(self):
        state = {"automatic": True, "launch_count": 1, "before_install_paths": [], "results": [],
                 "prepared_corpus": {"sample.hwp": [10, 123, "sha256"]}}
        events = []
        with patch.object(smoke, "corpus_snapshot", return_value=state["prepared_corpus"]), \
             patch.object(smoke, "assert_automatic_candidate_unchanged"), \
             patch.object(smoke, "discover", return_value=True), \
             patch.object(smoke, "index", side_effect=lambda _: events.append("index")), \
             patch.object(smoke, "verify", side_effect=lambda _: events.append("metadata")):
            smoke.automatic_search(state)
        self.assertEqual(events, ["index", "metadata"])
        state["results"] = []
        with patch.object(smoke, "corpus_snapshot", return_value=state["prepared_corpus"]), \
             patch.object(smoke, "assert_automatic_candidate_unchanged"), \
             patch.object(smoke, "discover", return_value=True), \
             patch.object(smoke, "index", side_effect=RuntimeError("no indexed documents")), \
             patch.object(smoke, "verify") as metadata:
            with self.assertRaises(RuntimeError): smoke.automatic_search(state)
            metadata.assert_not_called()
        self.assertEqual(state["results"], [])

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
