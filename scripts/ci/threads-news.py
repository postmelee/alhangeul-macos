#!/usr/bin/env python3
"""Threads 본인 글을 선별해 링크 전용 snapshot을 검증·저장한다. 공개 배포는 하지 않는다."""

import argparse
from collections import Counter
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
import getpass
from html.parser import HTMLParser
from http.client import HTTPException
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile
import time
import unicodedata
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qsl, urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
import warnings

API_ROOT = "https://graph.threads.net/v1.0/"
OEMBED_URL = "https://graph.threads.com/v1.0/oembed"
EXPECTED_USERNAME = "postmelee"
EXPECTED_TOPIC = "알한글"
EXAMPLE_SHORTCODE = "DdTIl2SEsaU"
MAX_BYTES = 4 * 1024 * 1024
MAX_ITEMS = 10000
POST_FIELDS = (
    "id,media_product_type,media_type,owner,username,text,topic_tag,timestamp,"
    "shortcode,permalink,is_quote_post,reposted_post,media_url,thumbnail_url,"
    "children,alt_text,text_attachment,ghost_post_status"
)
SYNC_FIELDS = (
    "id,media_product_type,media_type,owner,username,topic_tag,timestamp,"
    "shortcode,permalink,is_quote_post,reposted_post,ghost_post_status"
)
POST_TYPES = {"TEXT_POST", "IMAGE", "VIDEO", "CAROUSEL_ALBUM", "AUDIO", "REPOST_FACADE"}
THREADS_HOSTS = {"threads.com", "www.threads.com", "threads.net", "www.threads.net"}
MEDIA_DOMAINS = {"cdninstagram.com", "fbcdn.net", "fbsbx.com"}


class NewsError(Exception):
    """입력값과 API 오류 본문을 포함하지 않는 표시 가능한 오류."""


def require(condition, message):
    if not condition:
        raise NewsError(message)


def clean_text(value, maximum, label, *, empty=False):
    require(isinstance(value, str), label + " 문자열 필요")
    require((empty or bool(value)) and len(value) <= maximum, label + " 길이 오류")
    require(not any(0xD800 <= ord(c) <= 0xDFFF for c in value), label + " Unicode 오류")
    require(not any(ord(c) < 32 and c not in "\n\r\t" for c in value), label + " 제어 문자 오류")
    return value


def identifier(value):
    require(isinstance(value, str) and re.fullmatch(r"[0-9]{1,64}", value), "ID 형식 오류")
    return value


def utc_time(value):
    clean_text(value, 40, "시각")
    require(re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:?\d{2})", value), "시각 형식 오류")
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
        require(result.utcoffset() == timedelta(0), "UTC 시각 필요")
        return result
    except ValueError:
        raise NewsError("유효하지 않은 시각") from None


def normalized_topic(value):
    return unicodedata.normalize("NFC", clean_text(value, 100, "주제 태그").strip())


def public_url(value, *, media=False, username=EXPECTED_USERNAME):
    clean_text(value, 8192, "URL")
    require(not any(c.isspace() or ord(c) < 32 for c in value) and "\\" not in value, "URL 문자 오류")
    try:
        url = urlsplit(value)
        require(url.scheme == "https" and url.hostname and not url.username and not url.password
                and url.port is None and not url.fragment, "HTTPS URL 형식 오류")
        require(not any(k.lower() in {"access_token", "token", "client_secret", "authorization"}
                        for k, _ in parse_qsl(url.query)), "URL에 인증 매개변수 금지")
        if media:
            require(any(url.hostname == d or url.hostname.endswith("." + d) for d in MEDIA_DOMAINS),
                    "확인되지 않은 미디어 host")
        else:
            require(url.hostname in THREADS_HOSTS and not url.query, "정규 Threads 원문 URL 필요")
            match = re.fullmatch(r"/@?([A-Za-z0-9._]+)/post/([A-Za-z0-9_-]+)/?", url.path)
            require(match and match.group(1) == username, "원문 URL 작성자 또는 경로 오류")
        return value
    except ValueError:
        raise NewsError("URL 파싱 오류") from None


def exact_keys(obj, required, optional=()):
    require(isinstance(obj, dict), "객체 필요")
    require(set(required) <= obj.keys() and obj.keys() <= set(required) | set(optional),
            "필수 필드 누락 또는 허용하지 않은 필드")


def validate_news(data):
    """공개 계약 v2는 표시용 원문 참조만 허용한다. 날짜 정렬은 비공개 수집기 책임이다."""
    exact_keys(data, {"schema_version", "updated_at", "expires_at", "items"})
    require(type(data["schema_version"]) is int and data["schema_version"] == 2, "스키마 버전 오류")
    items = data["items"]
    require(isinstance(items, list) and len(items) <= MAX_ITEMS, "게시물 배열 또는 크기 오류")
    if data["updated_at"] is None:
        require(data["expires_at"] is None and not items, "비활성 초기값은 빈 목록 필요")
    else:
        updated, expires = utc_time(data["updated_at"]), utc_time(data["expires_at"])
        require(timedelta(0) < expires - updated <= timedelta(hours=48), "표시 유효기간은 최대 48시간")
    seen = set()
    for item in items:
        exact_keys(item, {"platform", "permalink"})
        require(item["platform"] == "threads", "현재 지원하지 않는 플랫폼")
        public_url(item["permalink"])
        # 같은 shortcode의 .net/.com URL 별칭도 중복으로 취급한다.
        key = (item["platform"], urlsplit(item["permalink"]).path.rstrip("/").rsplit("/", 1)[-1])
        require(key not in seen, "중복 게시물")
        seen.add(key)
    return {"status": "valid", "schema_version": 2, "item_count": len(items), "live_verified": False}


def validate_embed(data, permalink):
    """공식 응답의 원문 대응만 검증한다. 반환 HTML을 실행·저장·재게시하지 않는다."""
    public_url(permalink)
    shortcode = urlsplit(permalink).path.rstrip("/").rsplit("/", 1)[-1]
    exact_keys(data, {"type", "version", "html", "provider_name", "provider_url", "width"})
    require(data["type"] == "rich" and data["version"] == "1.0"
            and data["provider_name"] == "Threads"
            and data["provider_url"] in {"https://www.threads.com/", "https://www.threads.net/"},
            "oEmbed 제공자 또는 형식 오류")
    require(type(data["width"]) is int and 320 <= data["width"] <= 658, "oEmbed 너비 오류")
    html = clean_text(data["html"], 100000, "oEmbed HTML")

    class EmbedReference(HTMLParser):
        def __init__(self):
            super().__init__()
            self.references, self.scripts = [], []

        def handle_starttag(self, tag, attrs):
            attributes = dict(attrs)
            require(len(attributes) == len(attrs), "oEmbed 중복 속성")
            require(not any(key.lower().startswith("on") for key in attributes), "oEmbed 이벤트 속성 금지")
            if tag == "blockquote":
                require("text-post-media" in attributes.get("class", "").split()
                        and attributes.get("data-text-post-version") == "0", "oEmbed 컨테이너 오류")
                self.references.append(attributes.get("data-text-post-permalink"))
            if tag == "script":
                self.scripts.append(attributes.get("src"))

        handle_startendtag = handle_starttag

    parser = EmbedReference()
    parser.feed(html)
    parser.close()
    require(len(parser.references) == 1 and parser.scripts == ["https://www.threads.com/embed.js"],
            "oEmbed 원문 또는 script 계약 오류")
    reference = parser.references[0]
    clean_text(reference, 8192, "oEmbed 원문")
    require(not any(c.isspace() for c in reference) and "\\" not in reference, "oEmbed 원문 문자 오류")
    parsed = urlsplit(reference)
    require(parsed.scheme == "https" and parsed.netloc in THREADS_HOSTS and not parsed.fragment,
            "oEmbed 원문 host 오류")
    require(parsed.path.rstrip("/") in {"/t/" + shortcode, "/@postmelee/post/" + shortcode},
            "oEmbed 원문 shortcode 불일치")
    require(all(key in {"utm_source", "utm_campaign"} for key, _ in parse_qsl(parsed.query)),
            "oEmbed 원문 query 오류")
    return {"platform": "threads", "permalink": permalink}


class JsonTransport:
    """고정 URL 요청의 제한 시간과 재시도. 오류 본문·인증 URL은 밖으로 전달하지 않는다."""
    def __init__(self, *, opener=None, deadline_seconds=90, attempts=1,
                 clock=time.monotonic, sleep=time.sleep):
        require(type(attempts) is int and 1 <= attempts <= 3, "재시도 상한 오류")
        self.opener = opener or build_opener(NoRedirect())
        self.clock, self.sleep = clock, sleep
        self.deadline = clock() + deadline_seconds
        self.attempts = attempts

    def get(self, request, label):
        for attempt in range(self.attempts):
            remaining = self.deadline - self.clock()
            require(remaining > 0, label + " 시간 제한 초과")
            delay = 2 ** attempt
            try:
                with self.opener.open(request, timeout=min(15, remaining)) as response:
                    require(response.status == 200, label + " 비정상 HTTP 응답")
                    data = parse_json(response.read(MAX_BYTES + 1))
                    require(self.clock() <= self.deadline, label + " 시간 제한 초과")
                    return data
            except HTTPError as error:
                code = error.code
                retry_after = error.headers.get("Retry-After") if error.headers else None
                error.close()
                if code != 429 and not 500 <= code <= 599:
                    raise NewsError(label + " HTTP " + str(code)) from None
                if retry_after:
                    delay = retry_delay(retry_after, delay)
                message = label + " HTTP " + str(code) + " 재시도 소진"
            except (URLError, TimeoutError, OSError, HTTPException):
                message = label + " 연결 실패 또는 timeout"
            require(attempt + 1 < self.attempts, message)
            require(delay < self.deadline - self.clock(), label + " 재시도 대기 시간 제한 초과")
            self.sleep(delay)
        raise NewsError(label + " 요청 실패")


def retry_delay(value, fallback, *, now=None):
    if re.fullmatch(r"[0-9]{1,10}", value.strip()):
        return int(value.strip())
    try:
        when = parsedate_to_datetime(value)
        if when.tzinfo is not None:
            return max(0, (when - (now or datetime.now(timezone.utc))).total_seconds())
    except (ValueError, TypeError, OverflowError):
        pass
    return fallback


class OEmbedClient:
    """인증 client와 분리한다. 사용자 토큰을 받거나 공개 API에 전송하지 않는다."""
    def __init__(self, **transport_options):
        self._transport = JsonTransport(**transport_options)

    def check(self, permalink):
        public_url(permalink)
        request = Request(OEMBED_URL + "?" + urlencode({"url": permalink}),
                          headers={"Accept": "application/json", "User-Agent": "alhangeul-threads-probe/1"})
        data = self._transport.get(request, "oEmbed")
        return validate_embed(data, permalink)


def parse_json(raw):
    require(len(raw) <= MAX_BYTES, "JSON 크기 제한 초과")

    def pairs(values):
        result = {}
        for key, value in values:
            require(key not in result, "JSON 중복 키")
            result[key] = value
        return result

    def reject_constant(_):
        raise NewsError("JSON 비표준 숫자")

    try:
        return json.loads(raw, object_pairs_hook=pairs, parse_constant=reject_constant)
    except (ValueError, UnicodeError, RecursionError):
        raise NewsError("JSON 형식 오류") from None


def read_json(path):
    with Path(path).open("rb") as stream:
        return parse_json(stream.read(MAX_BYTES + 1))


def read_token(path=None):
    if path:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        try:
            info = os.fstat(fd)
            require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid()
                    and not info.st_mode & 0o077, "토큰 파일은 본인 소유 일반 파일·권한 600 필요")
        except BaseException:
            os.close(fd)
            raise
        with os.fdopen(fd, "rb") as stream:
            try:
                raw = stream.read(8193)
                require(len(raw) <= 8192, "토큰 파일 크기 제한 초과")
                token = raw.decode("ascii").strip()
            except UnicodeError:
                raise NewsError("토큰 형식 오류") from None
    elif os.environ.get("THREADS_ACCESS_TOKEN"):
        token = os.environ["THREADS_ACCESS_TOKEN"]
    else:
        require(sys.stdin.isatty(), "토큰 미설정: 사용자 터미널의 숨김 입력 또는 --token-file 사용")
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("error", getpass.GetPassWarning)
                token = getpass.getpass("Threads 토큰 (화면에 표시되지 않음): ")
        except (getpass.GetPassWarning, EOFError):
            raise NewsError("숨김 토큰 입력을 사용할 수 없음") from None
    require(isinstance(token, str) and 1 <= len(token) <= 8192
            and all(33 <= ord(c) <= 126 for c in token), "토큰 형식 오류")
    return token


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise NewsError("API redirect 거부")


class ThreadsClient:
    def __init__(self, token, **transport_options):
        self._token = token
        self._transport = JsonTransport(**transport_options)

    def get(self, endpoint, params):
        require(endpoint in {"me", "me/threads"}, "허용하지 않은 API endpoint")
        require(set(params) <= {"fields", "limit", "after"}, "허용하지 않은 API 매개변수")
        # 공식 예제의 query 인증을 사용한다. URL/예외/응답 전문은 절대 출력하지 않는다.
        request = Request(API_ROOT + endpoint + "?" + urlencode(dict(params, access_token=self._token)),
                          headers={"Accept": "application/json", "User-Agent": "alhangeul-threads-probe/1"})
        data = self._transport.get(request, "Threads API")
        require(isinstance(data, dict) and "error" not in data, "Threads API 오류 또는 응답 형식 오류")
        return data


def post_reason(post, account_id):
    """완전한 fields 조회에서만 사용. 누락 의미는 공식 조회 문서에 따른다."""
    require(isinstance(post, dict), "게시물 객체 오류")
    identifier(post.get("id"))
    require(post.get("media_product_type") == "THREADS", "게시물 surface 오류")
    kind = post.get("media_type")
    require(kind in POST_TYPES, "게시물 media_type 누락 또는 미지원")
    if kind == "REPOST_FACADE" or post.get("reposted_post") is not None:
        return "repost"
    if post.get("ghost_post_status") is not None:
        return "ghost_post"
    # /me/threads는 답글을 제외하며 owner는 본인 최상위 글에만 반환된다.
    if post.get("is_reply") is True:
        return "reply"
    owner = post.get("owner")
    if not isinstance(owner, dict) or not isinstance(owner.get("id"), str) or not post.get("username"):
        return "identity_unverified"
    if owner["id"] != account_id or post["username"] != EXPECTED_USERNAME:
        return "other_author"
    topic = post.get("topic_tag")
    if topic is None:
        return "no_topic"
    if normalized_topic(topic) != EXPECTED_TOPIC:
        return "other_topic"
    if not post.get("permalink"):
        return "no_permalink"
    public_url(post["permalink"])
    shortcode = post.get("shortcode")
    require(isinstance(shortcode, str) and re.fullmatch(r"[A-Za-z0-9_-]{1,100}", shortcode),
            "게시물 shortcode 오류")
    require(urlsplit(post["permalink"]).path.rstrip("/").endswith("/" + shortcode),
            "shortcode와 원문 URL 불일치")
    utc_time(post.get("timestamp"))
    if type(post.get("is_quote_post")) is not bool:
        return "quote_unverified"
    return "candidate"


def probe(client, *, max_pages=5, expected_user_id=None, example_shortcode=EXAMPLE_SHORTCODE,
          embed_client=None, reference_sink=None, strict=False, fields=POST_FIELDS,
          now=lambda: datetime.now(timezone.utc), excluded_shortcodes=frozenset()):
    require(type(max_pages) is int and 1 <= max_pages <= 200, "페이지 상한은 1~200")
    require(re.fullmatch(r"[A-Za-z0-9_-]{1,100}", example_shortcode), "예시 shortcode 형식 오류")
    me = client.get("me", {"fields": "id,username"})
    account_id = identifier(me.get("id"))
    require(me.get("username") == EXPECTED_USERNAME, "연결 계정이 postmelee가 아님")
    if expected_user_id is not None:
        require(account_id == identifier(expected_user_id), "고정 계정 ID 불일치")
    counts, present = Counter(), Counter()
    seen, cursors, observed_times = {}, set(), []
    cursor, pages, example_reason, exhausted = None, 0, None, False
    candidates = []
    for _ in range(max_pages):
        params = {"fields": fields, "limit": 50}
        if cursor:
            params["after"] = cursor
        page = client.get("me/threads", params)
        rows = page.get("data")
        require(isinstance(rows, list) and len(rows) <= 50, "게시물 페이지 형식/크기 오류")
        pages += 1
        for row in rows:
            reason = post_reason(row, account_id)
            if reason == "candidate" and row["shortcode"] in excluded_shortcodes:
                reason = "operator_excluded"
            if strict:
                require(reason not in {"identity_unverified", "quote_unverified", "no_permalink"},
                        "작성자·인용·원문 판정 필드 부족")
                require("is_reply" not in row or type(row["is_reply"]) is bool, "답글 판정 형식 오류")
            if row["id"] in seen:
                require(not strict or seen[row["id"]] == row, "중복 게시물 응답 충돌")
                counts["duplicate"] += 1
                continue
            seen[row["id"]] = row if strict else None
            require(len(seen) <= MAX_ITEMS, "게시물 조사 개수 제한 초과")
            counts[reason] += 1
            if reason == "candidate" and embed_client is not None:
                candidates.append((utc_time(row["timestamp"]), row["id"], row["permalink"]))
            for name in fields.split(","):
                if name in row:
                    present[name] += 1
            if "timestamp" in row:
                observed_times.append(utc_time(row["timestamp"]))
            if row.get("shortcode") == example_shortcode:
                example_reason = reason
        paging = page.get("paging", {})
        require(isinstance(paging, dict), "페이지네이션 형식 오류")
        # 공식 예제는 next 없이 cursors만 반환하기도 한다. after가 있으면 빈 페이지까지 조사한다.
        page_cursors = paging.get("cursors", {})
        require(isinstance(page_cursors, dict), "cursor 객체 오류")
        after = page_cursors.get("after")
        if after is not None:
            clean_text(after, 4096, "cursor")
        if not rows or after is None:
            require(not paging.get("next"), "다음 페이지가 있으나 안전한 cursor를 얻을 수 없음")
            exhausted = True
            break
        require(after not in cursors, "반복 cursor")
        cursors.add(after)
        cursor = after
    result = {
        "status": "probe_complete" if exhausted else "probe_partial",
        "account": {"id": account_id, "username": EXPECTED_USERNAME},
        "api_version": "v1.0", "requested_fields": fields.split(","),
        "pages": pages, "unique_posts": len(seen), "classification_counts": dict(counts),
        "field_presence_counts": dict(present), "pagination_exhausted": exhausted,
        "oldest_observed_at": min(observed_times).isoformat() if observed_times else None,
        "newest_observed_at": max(observed_times).isoformat() if observed_times else None,
        "example_shortcode": example_shortcode, "example_classification": example_reason or "not_observed",
        "stage1_complete": False,
        "note": "요약은 게시물 본문/토큰을 포함하지 않음. 전체 과거 글·삭제 판별·운영 적합성은 별도 확인 필요",
    }
    if embed_client is not None:
        result["embed_check"] = {"status": "skipped_partial_scan", "validated_count": 0}
        if exhausted:
            references = [embed_client.check(url) for _, _, url in
                          sorted(candidates, key=lambda item: (item[0], int(item[1])), reverse=True)]
            collected_at = now().replace(microsecond=0)
            manifest = {"schema_version": 2, "updated_at": collected_at.isoformat(),
                        "expires_at": (collected_at + timedelta(hours=48)).isoformat(), "items": references}
            validate_news(manifest)
            result["embed_check"] = {"status": "complete", "validated_count": len(references),
                                     "authenticated": False, "public_schema_version": 2}
            if reference_sink is not None:
                reference_sink(manifest)
    return result


def token_status(expires_at, *, now=None):
    if not expires_at:
        return {"status": "unknown", "expires_at": None, "renewal_required": True}
    expires = utc_time(expires_at)
    remaining = expires - (now or datetime.now(timezone.utc))
    status = "expired" if remaining <= timedelta(0) else "renewal_due" if remaining <= timedelta(days=14) else "valid"
    return {"status": status, "expires_at": expires.isoformat(), "renewal_required": status != "valid"}


def atomic_write(path, raw):
    """같은 디렉터리의 임시 파일을 검증한 결과로만 교체한다. 교체 이전 실패는 기존 파일을 보존한다."""
    path = Path(path)
    if path.exists() or path.is_symlink():
        info = path.lstat()
        require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid() and info.st_nlink == 1,
                "출력 대상은 본인 소유 일반 파일 필요")
    fd, temporary = tempfile.mkstemp(prefix=".threads-news-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def sync(client, embed_client, *, expected_user_id, output=None, max_pages=200,
         expires_at=None, dry_run=False, token=None, excluded_urls=(), now=lambda: datetime.now(timezone.utc)):
    identifier(expected_user_id)
    require(dry_run or output is not None, "수집 출력 파일 필요")
    if output is not None:
        require(Path(output).suffix == ".json", "snapshot 출력은 .json 파일 필요")
    def check_expiry():
        status = token_status(expires_at, now=now())
        require(status["status"] != "expired", "토큰 만료: 재인증 필요")
        require(dry_run or status["status"] != "unknown", "토큰 만료 시각 필요 (미확인 토큰은 dry-run만 허용)")
        return status
    check_expiry()
    require(isinstance(excluded_urls, (list, tuple)) and len(excluded_urls) <= MAX_ITEMS, "제외 목록 형식 오류")
    excluded = set()
    for url in excluded_urls:
        public_url(url)
        shortcode = urlsplit(url).path.rstrip("/").rsplit("/", 1)[-1]
        require(shortcode not in excluded, "제외 목록 중복")
        excluded.add(shortcode)
    manifest = {}
    result = probe(client, max_pages=max_pages, expected_user_id=expected_user_id,
                   embed_client=embed_client, reference_sink=manifest.update,
                   strict=True, fields=SYNC_FIELDS, now=now, excluded_shortcodes=excluded)
    require(result["pagination_exhausted"], "불완전 조회: 기존 snapshot 보존")
    validate_news(manifest)
    expiry = check_expiry()
    summary = {"status": "sync_dry_run" if dry_run else "sync_complete",
               "pages": result["pages"], "unique_posts": result["unique_posts"],
               "classification_counts": result["classification_counts"],
               "item_count": len(manifest["items"]), "updated_at": manifest["updated_at"],
               "expires_at": manifest["expires_at"], "token": expiry, "published": False}
    serialized = json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    if token:
        require(token not in serialized and token not in json.dumps(summary, ensure_ascii=False),
                "수집 결과에 인증 값 포함: 저장·출력 중단")
    if not dry_run:
        atomic_write(output, serialized.encode("utf-8"))
    return summary


def renew_token(token, *, expires_at, output, issued_at=None, app_secret=None,
                transport=None, now=lambda: datetime.now(timezone.utc)):
    """운영자가 명시적으로 실행하는 토큰 교환/갱신. 자동 수집 workflow에서는 사용하지 않는다."""
    started = now().replace(microsecond=0)
    require(token_status(expires_at, now=started)["status"] in {"valid", "renewal_due"},
            "토큰 교환·갱신은 확인된 미만료 토큰 필요")
    if app_secret is None:
        require(issued_at is not None and started - utc_time(issued_at) >= timedelta(hours=24),
                "장기 토큰 갱신은 발급/이전 갱신 후 24시간 경과 필요")
        endpoint, grant = "refresh_access_token", "th_refresh_token"
    else:
        endpoint, grant = "access_token", "th_exchange_token"
    target = Path(output)
    require(not target.exists() and not target.is_symlink(), "새 토큰 출력 파일은 기존 파일을 덮어쓸 수 없음")
    # 토큰 출력 디렉터리는 다른 사용자에게 노출하지 않는다.
    info = target.parent.stat()
    require(info.st_uid == os.getuid() and not info.st_mode & 0o077, "토큰 출력 디렉터리는 본인 소유·권한 700 필요")
    params = {"grant_type": grant, "access_token": token}
    if app_secret is not None:
        params["client_secret"] = app_secret
    request = Request("https://graph.threads.net/" + endpoint + "?" + urlencode(params),
                      headers={"Accept": "application/json"})
    data = (transport or JsonTransport()).get(request, "토큰 API")
    require(isinstance(data, dict) and "error" not in data, "토큰 응답 오류")
    new_token = data.get("access_token")
    require(isinstance(new_token, str) and 1 <= len(new_token) <= 8192
            and all(33 <= ord(c) <= 126 for c in new_token), "발급 토큰 형식 오류")
    seconds = data.get("expires_in")
    token_type = data.get("token_type", "bearer")
    require(type(seconds) is int and 0 < seconds <= 60 * 24 * 3600
            and isinstance(token_type, str) and token_type.lower() == "bearer", "토큰 유효기간·유형 응답 오류")
    expires = started + timedelta(seconds=seconds)
    require(expires > now(), "발급 토큰이 이미 만료됨")
    result = {"status": "token_exchanged" if app_secret is not None else "token_refreshed",
              "issued_at": started.isoformat(), "expires_at": expires.isoformat(),
              "secret_updated": False}
    require(all(secret not in json.dumps(result) for secret in (token, new_token, app_secret) if secret),
            "토큰 결과 요약에 인증 값 포함")
    fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(new_token)
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        target.unlink()
        raise
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    check = commands.add_parser("validate", help="공개 JSON 계약 검증 (실제 수집 증거가 아님)")
    check.add_argument("file", type=Path)
    inspect = commands.add_parser("probe", help="본인 API 조회, 비밀 없는 요약만 출력")
    inspect.add_argument("--token-file", type=Path, help="본인 소유·권한 600 토큰 파일. 미지정 시 환경변수 또는 숨김 입력")
    inspect.add_argument("--expected-user-id", help="최초 연결에서 확인한 계정 ID")
    inspect.add_argument("--max-pages", type=int, default=5, help="조사 상한. 기본 5페이지, 최대 200")
    inspect.add_argument("--example-shortcode", default=EXAMPLE_SHORTCODE)
    inspect.add_argument("--check-embeds", action="store_true", help="완전 조회 후 대상 글의 공개 oEmbed를 인증 없이 검사")
    inspect.add_argument("--reference-output", type=Path,
                         help="--check-embeds 성공 시 로컬 검증용 링크 JSON을 새 파일로 저장 (기존 파일 덮어쓰기 금지)")
    collect = commands.add_parser("sync", help="완전 조회·공개 임베드 검증 후 링크 JSON 원자적 교체")
    collect.add_argument("--token-file", type=Path)
    collect.add_argument("--expected-user-id", required=True)
    collect.add_argument("--max-pages", type=int, default=200)
    collect.add_argument("--output", type=Path)
    collect.add_argument("--exclude-file", type=Path, help="운영자가 명시 제외할 정규 원문 URL의 JSON 배열")
    collect.add_argument("--dry-run", action="store_true", help="실제 조회·검증만 수행하며 파일·공개 사이트 변경 없음")
    collect.add_argument("--token-expires-at", default=os.environ.get("THREADS_TOKEN_EXPIRES_AT"), help="발급 응답에서 확인한 UTC 만료 시각")
    expiry = commands.add_parser("token-status", help="토큰 없이 기록된 UTC 만료 시각·14일 전 갱신 여부 확인")
    expiry.add_argument("--expires-at", default=os.environ.get("THREADS_TOKEN_EXPIRES_AT"))
    for name in ("refresh-token", "exchange-token"):
        renew = commands.add_parser(name, help="수동 토큰 갱신/교환. 새 보호 파일 저장, 비밀 출력·저장소 secret 갱신 없음")
        renew.add_argument("--token-file", type=Path)
        renew.add_argument("--expires-at", required=True)
        renew.add_argument("--output-token-file", type=Path, required=True)
        if name == "refresh-token":
            renew.add_argument("--issued-at", required=True, help="마지막 발급/갱신의 UTC 시각 (24시간 경과 필요)")
        else:
            renew.add_argument("--app-secret-file", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "validate":
            result = validate_news(read_json(args.file))
        elif args.command == "token-status":
            result = token_status(args.expires_at)
        elif args.command == "sync":
            token = read_token(args.token_file)
            result = sync(ThreadsClient(token, attempts=3, deadline_seconds=300),
                          OEmbedClient(attempts=3, deadline_seconds=300),
                          expected_user_id=args.expected_user_id, output=args.output,
                          max_pages=args.max_pages, expires_at=args.token_expires_at,
                          dry_run=args.dry_run, token=token,
                          excluded_urls=read_json(args.exclude_file) if args.exclude_file else ())
        elif args.command in {"refresh-token", "exchange-token"}:
            result = renew_token(read_token(args.token_file), expires_at=args.expires_at,
                                 output=args.output_token_file, issued_at=getattr(args, "issued_at", None),
                                 app_secret=read_token(args.app_secret_file) if args.command == "exchange-token" else None)
        else:
            require(not args.reference_output or args.check_embeds, "링크 출력에는 --check-embeds 필요")
            token = read_token(args.token_file)
            manifest = {}
            result = probe(ThreadsClient(token), max_pages=args.max_pages,
                           expected_user_id=args.expected_user_id, example_shortcode=args.example_shortcode,
                           embed_client=OEmbedClient(deadline_seconds=180) if args.check_embeds else None,
                           reference_sink=manifest.update if args.reference_output else None)
            require(token not in json.dumps(result, ensure_ascii=False), "요약에 인증 값 포함: 출력 중단")
            if args.reference_output and manifest:
                serialized = json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
                require(token not in serialized, "링크 결과에 인증 값 포함: 저장 중단")
                fd = os.open(args.reference_output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                with os.fdopen(fd, "w") as stream:
                    stream.write(serialized)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        if result.get("token", {}).get("renewal_required"):
            print("주의: 토큰 만료 시각 미확인 또는 14일 이내 만료. 운영 전 갱신 정보를 확인하세요.", file=sys.stderr)
        return 2 if result["status"] == "probe_partial" else 1 if result["status"] in {"unknown", "expired"} else 0
    except NewsError as error:
        print("오류: " + str(error), file=sys.stderr)
        return 1
    except (OSError, UnicodeError, ValueError, TypeError, RecursionError):
        print("오류: 파일·입력·응답 처리 실패 (비밀 보호를 위해 상세 생략)", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("취소됨", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
