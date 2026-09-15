#!/usr/bin/env python3
"""Stage 1: 실제 네트워크 없이 비밀 보호와 데이터/API 조사 계약을 검증한다."""

import copy
from http.client import IncompleteRead
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlsplit

HELPER = Path(__file__).with_name("threads-news.py")
FIXTURES = Path(__file__).with_name("fixtures") / "threads-news"
spec = importlib.util.spec_from_file_location("threads_news", HELPER)
news = importlib.util.module_from_spec(spec)
spec.loader.exec_module(news)


class FakeClient:
    def __init__(self, fixture):
        self.profile = fixture["profile"]
        self.pages = iter(fixture["pages"])
        self.calls = []

    def get(self, endpoint, params):
        self.calls.append((endpoint, params))
        return self.profile if endpoint == "me" else next(self.pages)


class NewsTests(unittest.TestCase):
    def setUp(self):
        self.data = news.read_json(FIXTURES / "public-news.json")
        self.fixture = news.read_json(FIXTURES / "probe-responses.json")

    def test_valid_and_empty_are_not_live_evidence(self):
        self.assertFalse(news.validate_news(self.data)["live_verified"])
        self.assertEqual(news.validate_news({"schema_version": 2, "updated_at": None,
                                            "expires_at": None, "items": []})["item_count"], 0)

    def test_unknown_fields_and_duplicates_rejected(self):
        for obj in (self.data, self.data["items"][0]):
            with self.subTest():
                obj["access_token"] = "synthetic-secret"
                with self.assertRaises(news.NewsError): news.validate_news(self.data)
                del obj["access_token"]
        self.data["items"].append(copy.deepcopy(self.data["items"][0]))
        with self.assertRaises(news.NewsError): news.validate_news(self.data)

    def test_public_manifest_rejects_copied_content_and_identity(self):
        for field, value in [("platform", "x"), ("id", "1001"), ("topic_tag", "알한글"),
                             ("text", "본문"), ("media", []), ("author", {"username": "postmelee"})]:
            data = copy.deepcopy(self.data); data["items"][0][field] = value
            with self.subTest(field=field), self.assertRaises(news.NewsError): news.validate_news(data)
        self.data["items"][0]["permalink"] = "https://www.threads.com/@someone/post/A"
        with self.assertRaises(news.NewsError): news.validate_news(self.data)

    def test_schema_and_manifest_lifetime(self):
        for field, value in [("schema_version", True), ("schema_version", 1), ("schema_version", 2.0),
                             ("updated_at", None), ("expires_at", None),
                             ("expires_at", "2026-09-15T00:00:00Z"),
                             ("expires_at", "2026-09-17T00:00:01Z"),
                             ("updated_at", "2026-09-15T00:00:00+09:00")]:
            data = copy.deepcopy(self.data); data[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(news.NewsError): news.validate_news(data)
        with self.assertRaises(news.NewsError): news.utc_time("2026-02-30T00:00:00Z")

    def test_alias_duplicates_are_rejected(self):
        alias = copy.deepcopy(self.data["items"][0])
        alias["permalink"] = alias["permalink"].replace("threads.com", "threads.net") + "/"
        self.data["items"].append(alias)
        with self.assertRaisesRegex(news.NewsError, "중복"): news.validate_news(self.data)

    def test_oembed_matches_reference_without_exposing_html(self):
        embed = news.read_json(FIXTURES / "oembed-response.json")
        ref = self.data["items"][0]
        self.assertEqual(news.validate_embed(embed, ref["permalink"]), ref)
        self.assertNotIn("html", news.validate_embed(embed, ref["permalink"]))

    def test_oembed_rejects_wrong_post_host_and_script(self):
        embed = news.read_json(FIXTURES / "oembed-response.json")
        for before, after in [("/t/SyntheticOnly", "/t/SomeoneElse"),
                              ("www.threads.com/t", "evil.test/t"),
                              ("https://www.threads.com/embed.js", "https://evil.test/embed.js"),
                              ("utm_source=th_embed", "access_token=secret"),
                              ('class="text-post-media"', 'class="text-post-media" onclick="alert(1)"'),
                              ('data-text-post-version="0"', 'data-text-post-version="1"')]:
            bad = copy.deepcopy(embed); bad["html"] = bad["html"].replace(before, after)
            with self.subTest(after=after), self.assertRaises(news.NewsError):
                news.validate_embed(bad, self.data["items"][0]["permalink"])
        for field, value in [("width", True), ("width", 1000), ("provider_name", "Other"), ("html", "")]:
            bad = copy.deepcopy(embed); bad[field] = value
            with self.subTest(field=field), self.assertRaises(news.NewsError):
                news.validate_embed(bad, self.data["items"][0]["permalink"])

    def test_oembed_client_has_no_credentials_or_arbitrary_endpoint(self):
        payload = json.dumps(news.read_json(FIXTURES / "oembed-response.json")).encode()
        class Opener:
            def open(self, request, timeout):
                self.request = request
                class Response(io.BytesIO): status = 200
                return Response(payload)
        opener = Opener()
        news.OEmbedClient(opener=opener).check(self.data["items"][0]["permalink"])
        parsed = urlsplit(opener.request.full_url)
        self.assertEqual((parsed.hostname, parsed.path), ("graph.threads.com", "/v1.0/oembed"))
        self.assertEqual(set(parse_qs(parsed.query)), {"url"})
        self.assertNotIn("Authorization", opener.request.headers)

    def test_embeds_require_complete_scan_and_all_pass_before_output(self):
        class EmbedClient:
            calls = 0
            def check(inner, url):
                inner.calls += 1
                return {"platform": "threads", "permalink": url}
        embeds, manifests = EmbedClient(), []
        partial = news.probe(FakeClient(self.fixture), max_pages=1, embed_client=embeds, reference_sink=manifests.append)
        self.assertEqual(partial["embed_check"]["status"], "skipped_partial_scan")
        self.assertEqual((embeds.calls, manifests), (0, []))
        result = news.probe(FakeClient(self.fixture), embed_client=embeds, reference_sink=manifests.append)
        self.assertEqual(result["embed_check"]["validated_count"], 1)
        self.assertEqual(set(manifests[0]["items"][0]), {"platform", "permalink"})
        class FailedEmbed:
            def check(inner, url): raise news.NewsError("oEmbed HTTP 404")
        manifests.clear()
        with self.assertRaises(news.NewsError):
            news.probe(FakeClient(self.fixture), embed_client=FailedEmbed(), reference_sink=manifests.append)
        self.assertEqual(manifests, [])

    def test_embed_references_preserve_latest_first_without_public_dates(self):
        old = copy.deepcopy(self.fixture["pages"][0]["data"][0])
        old.update(id="1009", timestamp="2020-01-01T00:00:00Z", shortcode="Older", permalink="https://www.threads.com/@postmelee/post/Older")
        self.fixture["pages"][0]["data"].insert(0, old)
        class Embeds:
            def check(inner, url): return {"platform": "threads", "permalink": url}
        manifests = []
        news.probe(FakeClient(self.fixture), embed_client=Embeds(), reference_sink=manifests.append)
        self.assertTrue(manifests[0]["items"][-1]["permalink"].endswith("/Older"))
        self.assertNotIn("timestamp", json.dumps(manifests))

    def test_json_rejects_duplicate_keys_nonfinite_and_size(self):
        for raw in [b'{"a":1,"a":2}', b'{"a":NaN}', b'{}' * news.MAX_BYTES, b'\xff']:
            with self.subTest(), self.assertRaises(news.NewsError): news.parse_json(raw)

    def test_url_boundaries(self):
        for url in ["javascript:alert(1)", "https://www.threads.com.evil.test/@postmelee/post/A",
                    "https://user:pass@www.threads.com/@postmelee/post/A",
                    "https://www.threads.com:443/@postmelee/post/A", "https://127.0.0.1/a",
                    "https://www.threads.com/@someone/post/A", "https://www.threads.com/share/A",
                    "https://www.threads.com/@postmelee/post/A?access_token=secret",
                    "https://www.threads.com/@postmelee/post/A\n"]:
            with self.subTest(url=url), self.assertRaises(news.NewsError): news.public_url(url)
        for url in ["https://cdninstagram.com.evil.test/a", "https://localhost/a", "https://fbcdn.net/a?%61ccess_token=x"]:
            with self.subTest(url=url), self.assertRaises(news.NewsError): news.public_url(url, media=True)

    def test_missing_optional_fields_follow_documented_contract(self):
        row = self.fixture["pages"][0]["data"][0]
        self.assertEqual(news.post_reason(row, "1234567"), "candidate")
        del row["topic_tag"]
        self.assertEqual(news.post_reason(row, "1234567"), "no_topic")
        row["topic_tag"] = "알한글"
        self.assertEqual(news.post_reason(row, "1234567"), "candidate")
        del row["owner"]
        self.assertEqual(news.post_reason(row, "1234567"), "identity_unverified")

    def test_repost_reply_ghost_other_author_and_missing_quote(self):
        original = self.fixture["pages"][0]["data"][0]
        for field, value, reason in [("media_type", "REPOST_FACADE", "repost"),
                                     ("reposted_post", {"id": "99"}, "repost"),
                                     ("is_reply", True, "reply"), ("ghost_post_status", "ACTIVE", "ghost_post"),
                                     ("owner", {"id": "9876"}, "other_author"),
                                     ("is_quote_post", None, "quote_unverified")]:
            row = copy.deepcopy(original); row[field] = value
            with self.subTest(field=field): self.assertEqual(news.post_reason(row, "1234567"), reason)

    def test_probe_summary_has_no_body_cursor_or_token_and_example_is_explicit(self):
        client = FakeClient(self.fixture)
        result = news.probe(client, example_shortcode="SyntheticOnly")
        self.assertEqual(result["classification_counts"], {"candidate": 1, "no_topic": 1})
        self.assertEqual(result["example_classification"], "candidate")
        self.assertTrue(result["pagination_exhausted"])
        self.assertFalse(result["stage1_complete"])
        output = json.dumps(result, ensure_ascii=False)
        self.assertNotIn("테스트 본문", output)
        self.assertNotIn("synthetic-after", output)
        self.assertEqual(client.calls[2][1]["after"], "synthetic-after")

    def test_partial_scan_not_complete(self):
        result = news.probe(FakeClient(self.fixture), max_pages=1)
        self.assertEqual(result["status"], "probe_partial")
        self.assertFalse(result["pagination_exhausted"])
        self.assertEqual(result["example_classification"], "not_observed")

    def test_wrong_account_stops_before_posts(self):
        for change in ["username", "id"]:
            fixture = copy.deepcopy(self.fixture); fixture["profile"][change] = "123456"
            client = FakeClient(fixture)
            with self.assertRaises(news.NewsError): news.probe(client, expected_user_id="1234567")
            self.assertEqual(len(client.calls), 1)

    def test_cursor_loop_and_unsafe_next_are_not_followed(self):
        self.fixture["pages"].append(copy.deepcopy(self.fixture["pages"][0]))
        self.fixture["pages"][1] = copy.deepcopy(self.fixture["pages"][0])
        with self.assertRaisesRegex(news.NewsError, "반복 cursor"): news.probe(FakeClient(self.fixture))
        page = self.fixture["pages"][0]
        page["paging"] = {"next": "https://evil.test/?access_token=synthetic-secret"}
        with self.assertRaisesRegex(news.NewsError, "안전한 cursor"): news.probe(FakeClient(self.fixture))

    def test_token_file_rejects_world_readable_symlink_and_directory(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "token"; path.write_text("synthetic-secret\n"); path.chmod(0o600)
            self.assertEqual(news.read_token(path), "synthetic-secret")
            path.chmod(0o644)
            with self.assertRaises(news.NewsError): news.read_token(path)
            link = Path(root) / "link"; link.symlink_to(path)
            with self.assertRaises(OSError): news.read_token(link)
            with self.assertRaises(news.NewsError): news.read_token(root)

    def test_client_auth_url_is_fixed_and_no_next_or_base_override(self):
        class Opener:
            def open(self, request, timeout):
                self.request, self.timeout = request, timeout
                class Response(io.BytesIO):
                    status = 200
                return Response(b'{"id":"1234567"}')
        opener = Opener(); client = news.ThreadsClient("synthetic-secret", opener=opener)
        self.assertEqual(client.get("me", {"fields": "id"})["id"], "1234567")
        parsed = urlsplit(opener.request.full_url)
        self.assertEqual(parsed.hostname, "graph.threads.net")
        self.assertEqual(parse_qs(parsed.query)["access_token"], ["synthetic-secret"])
        for endpoint in ["https://evil.test", "../me", "me/permissions"]:
            with self.assertRaises(news.NewsError): client.get(endpoint, {})
        with self.assertRaises(news.NewsError): client.get("me", {"access_token": "override"})

    def test_client_error_and_redirect_never_echo_token(self):
        secret = "synthetic-secret"
        for failure in [HTTPError("https://graph.threads.net/?access_token=" + secret, 400, secret, {}, io.BytesIO(secret.encode())),
                        URLError(secret), IncompleteRead(secret.encode()), TimeoutError(secret)]:
            class Opener:
                def open(self, request, timeout): raise failure
            with self.subTest(type=type(failure).__name__):
                try: news.ThreadsClient(secret, opener=Opener()).get("me", {})
                except news.NewsError as error: self.assertNotIn(secret, str(error))
                else: self.fail("failure accepted")
        with self.assertRaisesRegex(news.NewsError, "redirect"):
            news.NoRedirect().redirect_request(None, None, 302, secret, {}, "https://evil.test")

    def test_cli_missing_token_and_malformed_data_do_not_traceback(self):
        env = dict(os.environ); env.pop("THREADS_ACCESS_TOKEN", None)
        result = subprocess.run([sys.executable, str(HELPER), "probe"], input="", env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 1); self.assertIn("토큰 미설정", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "bad.json"; path.write_text('{"synthetic-secret":')
            result = subprocess.run([sys.executable, str(HELPER), "validate", str(path)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 1)
            self.assertNotIn("synthetic-secret", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
