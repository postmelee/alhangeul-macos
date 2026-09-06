#!/usr/bin/env python3
"""운영 smoke의 경로 소유권, 환경 대조, 반복 추출 판정 회귀 검사."""
import importlib.util
import json
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


if __name__ == "__main__":
    unittest.main()
