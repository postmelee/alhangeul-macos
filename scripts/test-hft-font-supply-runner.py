#!/usr/bin/env python3
"""진단 출력 위치 보호 회귀. 실제 글꼴·앱 저장소를 사용하지 않는다."""
import importlib.util
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('probe', Path(__file__).with_name('probe-hft-font-supply.py'))
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class OutputTests(unittest.TestCase):
    def test_preflight_failure_leaves_failed_result(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            out = root/'build.noindex'/'failed'
            with patch.object(probe, 'ROOT', root), \
                 patch.object(probe, 'output_directory', side_effect=lambda value: OutputTests.make_output(value, root)), \
                 patch.object(probe, 'command_text', side_effect=subprocess.CalledProcessError(1, 'git')), \
                 patch.object(sys, 'argv', ['probe','--mode','fixtures','--output-dir',str(out)]), \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(probe.main(), 1)
            result = json.loads((out/'result.json').read_text())
            self.assertEqual(result['failedPhase'], 'preflight')
            self.assertEqual(result['error'], 'probeExecutionFailed')
            self.assertNotIn('summary', result)
            self.assertFalse((out/'private-state').exists())

    make_output = staticmethod(probe.output_directory)

    def test_new_directory_only(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            out = probe.output_directory(root/'build.noindex'/'run',root)
            marker = out/'result.json'
            marker.write_text('preserve')
            with self.assertRaises(FileExistsError):
                probe.output_directory(out,root)
            self.assertEqual(marker.read_text(),'preserve')

    def test_external_and_base_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for value in [root/'outside',root/'build.noindex']:
                with self.assertRaises(ValueError):
                    probe.output_directory(value,root)

    def test_symlink_escape_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'build.noindex').mkdir()
            (root/'outside').mkdir()
            (root/'build.noindex'/'link').symlink_to(root/'outside',target_is_directory=True)
            with self.assertRaises(ValueError):
                probe.output_directory(root/'build.noindex'/'link'/'run',root)
            self.assertFalse((root/'outside'/'run').exists())

    def test_base_symlink_escape_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'outside').mkdir()
            (root/'build.noindex').symlink_to(root/'outside',target_is_directory=True)
            with self.assertRaises(ValueError):
                probe.output_directory(root/'build.noindex'/'run',root)
            self.assertFalse((root/'outside'/'run').exists())


if __name__ == '__main__':
    unittest.main()
