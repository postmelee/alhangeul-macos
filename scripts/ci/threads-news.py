#!/usr/bin/env python3
"""Threads 본인 게시물의 계약을 조사하고 공개 소식 JSON을 검증한다.

probe는 본문·토큰·원본 응답을 저장하거나 게시하지 않는다. 실제 계정 검증용이며
Stage 2의 수집·병합·배포 기능은 포함하지 않는다. Python 표준 라이브러리만 사용한다.
"""

import argparse
from collections import Counter
from datetime import datetime, timedelta, timezone
import getpass
from html.parser import HTMLParser
from http.client import HTTPException
import json
import os
from pathlib import Path
import re
import stat
import sys
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


class OEmbedClient:
    """인증 client와 분리한다. 사용자 토큰을 받거나 공개 API에 전송하지 않는다."""
    def __init__(self, *, opener=None, deadline_seconds=90):
        self._opener = opener or build_opener(NoRedirect())
        self._deadline = time.monotonic() + deadline_seconds

    def check(self, permalink):
        public_url(permalink)
        remaining = self._deadline - time.monotonic()
        require(remaining > 0, "oEmbed 조사 시간 제한 초과")
        request = Request(OEMBED_URL + "?" + urlencode({"url": permalink}),
                          headers={"Accept": "application/json", "User-Agent": "alhangeul-threads-probe/1"})
        try:
            with self._opener.open(request, timeout=min(15, remaining)) as response:
                require(response.status == 200, "oEmbed 비정상 HTTP 응답")
                data = parse_json(response.read(MAX_BYTES + 1))
                require(time.monotonic() <= self._deadline, "oEmbed 조사 시간 제한 초과")
        except HTTPError as error:
            status = error.code
            error.close()
            raise NewsError("oEmbed HTTP " + str(status) + " (공개 표시 상태 확인 필요)") from None
        except (URLError, TimeoutError, OSError, HTTPException):
            raise NewsError("oEmbed 연결 실패 또는 timeout") from None
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
    def __init__(self, token, *, opener=None, deadline_seconds=90):
        self._token = token
        self._opener = opener or build_opener(NoRedirect())
        self._deadline = time.monotonic() + deadline_seconds

    def get(self, endpoint, params):
        require(endpoint in {"me", "me/threads"}, "허용하지 않은 API endpoint")
        require(set(params) <= {"fields", "limit", "after"}, "허용하지 않은 API 매개변수")
        remaining = self._deadline - time.monotonic()
        require(remaining > 0, "API 조사 시간 제한 초과")
        # 공식 예제의 query 인증을 사용한다. URL/예외/응답 전문은 절대 출력하지 않는다.
        request = Request(API_ROOT + endpoint + "?" + urlencode(dict(params, access_token=self._token)),
                          headers={"Accept": "application/json", "User-Agent": "alhangeul-threads-probe/1"})
        try:
            with self._opener.open(request, timeout=min(15, remaining)) as response:
                require(response.status == 200, "API 비정상 HTTP 응답")
                data = parse_json(response.read(MAX_BYTES + 1))
                require(time.monotonic() <= self._deadline, "API 조사 시간 제한 초과")
        except HTTPError as error:
            code = error.code
            error.close()
            raise NewsError("Threads API HTTP " + str(code) + " (인증·권한·요청 필드 확인 필요)") from None
        except (URLError, TimeoutError, OSError, HTTPException):
            raise NewsError("Threads API 연결 실패 또는 timeout") from None
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
          embed_client=None, reference_sink=None):
    require(type(max_pages) is int and 1 <= max_pages <= 200, "페이지 상한은 1~200")
    require(re.fullmatch(r"[A-Za-z0-9_-]{1,100}", example_shortcode), "예시 shortcode 형식 오류")
    me = client.get("me", {"fields": "id,username"})
    account_id = identifier(me.get("id"))
    require(me.get("username") == EXPECTED_USERNAME, "연결 계정이 postmelee가 아님")
    if expected_user_id is not None:
        require(account_id == identifier(expected_user_id), "고정 계정 ID 불일치")
    counts, present = Counter(), Counter()
    seen, cursors, observed_times = set(), set(), []
    cursor, pages, example_reason, exhausted = None, 0, None, False
    candidates = []
    for _ in range(max_pages):
        params = {"fields": POST_FIELDS, "limit": 50}
        if cursor:
            params["after"] = cursor
        page = client.get("me/threads", params)
        rows = page.get("data")
        require(isinstance(rows, list) and len(rows) <= 50, "게시물 페이지 형식/크기 오류")
        pages += 1
        for row in rows:
            reason = post_reason(row, account_id)
            if row["id"] in seen:
                counts["duplicate"] += 1
                continue
            seen.add(row["id"])
            require(len(seen) <= MAX_ITEMS, "게시물 조사 개수 제한 초과")
            counts[reason] += 1
            if reason == "candidate" and embed_client is not None:
                candidates.append((utc_time(row["timestamp"]), row["id"], row["permalink"]))
            for name in POST_FIELDS.split(","):
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
        if not rows or not after:
            require(not paging.get("next"), "다음 페이지가 있으나 안전한 cursor를 얻을 수 없음")
            exhausted = True
            break
        clean_text(after, 4096, "cursor")
        require(after not in cursors, "반복 cursor")
        cursors.add(after)
        cursor = after
    result = {
        "status": "probe_complete" if exhausted else "probe_partial",
        "account": {"id": account_id, "username": EXPECTED_USERNAME},
        "api_version": "v1.0", "requested_fields": POST_FIELDS.split(","),
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
            references = [embed_client.check(url) for _, _, url in sorted(candidates, reverse=True)]
            now = datetime.now(timezone.utc).replace(microsecond=0)
            manifest = {"schema_version": 2, "updated_at": now.isoformat(),
                        "expires_at": (now + timedelta(hours=48)).isoformat(), "items": references}
            validate_news(manifest)
            result["embed_check"] = {"status": "complete", "validated_count": len(references),
                                     "authenticated": False, "public_schema_version": 2}
            if reference_sink is not None:
                reference_sink(manifest)
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
    args = parser.parse_args()
    try:
        if args.command == "validate":
            result = validate_news(read_json(args.file))
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
        return 2 if result["status"] == "probe_partial" else 0
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
