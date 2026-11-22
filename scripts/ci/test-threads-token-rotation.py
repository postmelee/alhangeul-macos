#!/usr/bin/env python3
import contextlib
from datetime import datetime, timedelta, timezone
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import unittest
from unittest.mock import Mock, call, patch


spec = importlib.util.spec_from_file_location(
    "rotation", Path(__file__).with_name("rotate-threads-token.py")
)
rotation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rotation)


class RotationTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 11, 22, tzinfo=timezone.utc)
        self.updated = self.now - timedelta(days=45)
        self.expires = self.now + timedelta(days=13)
        self.new_expiry = self.now + timedelta(days=60)
        self.repo = Mock(spec=rotation.Repository)
        self.repo.metadata.return_value = (self.updated, self.expires)

    def cycle(self, *, verify=False):
        return rotation.rotate(self.repo, "synthetic-existing", "12345", self.expires,
                               verify_only=verify)

    def test_success_with_both_persisted_in_order(self):
        self.repo.metadata.side_effect = [
            (self.updated, self.expires),
            (self.updated, self.expires),
            (self.now, self.new_expiry),
        ]
        with patch.object(rotation, "utc_now", return_value=self.now), \
                patch.object(rotation, "refresh", return_value=("synthetic-new", self.new_expiry)), \
                patch.object(rotation, "verify_account") as verify:
            self.assertEqual(self.cycle(), "rotated")
        self.assertEqual(verify.call_args_list, [
            call("synthetic-existing", "12345"), call("synthetic-new", "12345")
        ])
        self.assertEqual([item[0] for item in self.repo.mock_calls],
                         ["metadata", "metadata", "write_secret", "write_expiry", "metadata"])
        self.repo.write_expiry.assert_called_once_with(self.new_expiry)

    def test_manual_run_only_verifies(self):
        with patch.object(rotation, "utc_now", return_value=self.now), \
                patch.object(rotation, "refresh") as refresh, \
                patch.object(rotation, "verify_account") as verify:
            self.assertEqual(self.cycle(verify=True), "verify_only")
        verify.assert_called_once_with("synthetic-existing", "12345")
        refresh.assert_not_called()
        self.repo.write_secret.assert_not_called()
        self.repo.write_expiry.assert_not_called()

    def test_stale_snapshot_never_writes(self):
        self.repo.metadata.return_value = (self.updated, self.new_expiry)
        with patch.object(rotation, "refresh") as refresh:
            with self.assertRaises(rotation.RotationError):
                self.cycle()
        refresh.assert_not_called()
        self.repo.write_secret.assert_not_called()

    def test_partial_failure_cannot_report_success(self):
        self.repo.write_expiry.side_effect = rotation.RotationError("Secret 저장 후 만료일 갱신 실패")
        with patch.object(rotation, "utc_now", return_value=self.now), \
                patch.object(rotation, "refresh", return_value=("synthetic-new", self.new_expiry)), \
                patch.object(rotation, "verify_account"):
            with self.assertRaisesRegex(rotation.RotationError, "만료일 갱신 실패"):
                self.cycle()
        self.repo.write_secret.assert_called_once_with("synthetic-new")

    def test_rejected_account_cannot_write(self):
        wrong_profile = {"id": "99999", "username": "postmelee"}
        with patch.object(rotation, "utc_now", return_value=self.now), \
                patch.object(rotation, "refresh", return_value=("synthetic-new", self.new_expiry)), \
                patch.object(rotation.news.ThreadsClient, "get", return_value=wrong_profile):
            with self.assertRaisesRegex(rotation.RotationError, "불일치"):
                self.cycle()
        self.repo.write_secret.assert_not_called()

    def test_secret_is_sent_stdin_and_child_errors_are_not_printed(self):
        repo = rotation.Repository("synthetic-installation")
        fake_result = subprocess.CompletedProcess(
            [], 1, b"synthetic-new", b"synthetic-installation synthetic-new"
        )
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err), \
                patch.object(rotation.subprocess, "run", return_value=fake_result) as run, \
                patch.object(rotation.time, "sleep"):
            with self.assertRaises(rotation.RotationError) as raised:
                repo.write_secret("synthetic-new")
        self.assertEqual(run.call_count, 3)
        self.assertEqual(run.call_args.kwargs["input"], b"synthetic-new")
        self.assertNotIn("synthetic-new", run.call_args.args[0])
        self.assertNotIn("synthetic", out.getvalue() + err.getvalue() + str(raised.exception))

    def test_meta_response_and_exception_do_not_expose_token(self):
        with patch.object(rotation.news.JsonTransport, "get",
                          return_value={"access_token": "synthetic-new", "expires_in": 60 * 24 * 60 * 60}):
            self.assertEqual(rotation.refresh("synthetic-existing", self.now),
                             ("synthetic-new", self.new_expiry))
        with patch.object(rotation.news.JsonTransport, "get",
                          side_effect=RuntimeError("secret=synthetic-existing")):
            with self.assertRaises(rotation.RotationError) as raised:
                rotation.refresh("synthetic-existing", self.now)
        self.assertNotIn("synthetic-existing", str(raised.exception))

    def test_expiry_check_runs_without_a_secret(self):
        for remaining, expected in [(timedelta(days=14), "true"), (timedelta(days=15), "false")]:
            with self.subTest(remaining=remaining):
                out = io.StringIO()
                env = {rotation.EXPIRY: (self.now + remaining).isoformat()}
                with patch.dict(os.environ, env, clear=True), patch.object(rotation, "utc_now", return_value=self.now), \
                        patch.object(rotation.sys, "argv", ["rotation", "due"]), contextlib.redirect_stdout(out):
                    self.assertEqual(rotation.main(), 0)
                self.assertEqual(out.getvalue().strip(), expected)


if __name__ == "__main__":
    unittest.main()
