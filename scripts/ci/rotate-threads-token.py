#!/usr/bin/env python3
"""Refresh the production Threads token without logging credentials or upstream responses."""

import argparse
from datetime import datetime, timedelta, timezone
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import time


_SPEC = importlib.util.spec_from_file_location(
    "threads_news", Path(__file__).with_name("threads-news.py")
)
news = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(news)

REPOSITORY = "postmelee/alhangeul-macos"
SECRET = "THREADS_ACCESS_TOKEN"
EXPIRY = "THREADS_TOKEN_EXPIRES_AT"
BASE = f"repos/{REPOSITORY}/actions"


class RotationError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise RotationError(message)


def utc_now():
    return datetime.now(timezone.utc).replace(microsecond=0)


class Repository:
    def __init__(self, token):
        require(bool(token), "GitHub App 설치 토큰이 없습니다.")
        # Debug flags and the current Threads credential must not reach gh.
        self.environment = {
            "PATH": os.defpath + ":/usr/local/bin",
            "GH_TOKEN": token,
            "GH_PROMPT_DISABLED": "1",
            "GH_NO_UPDATE_NOTIFIER": "1",
        }

    def run(self, args, *, secret=None, label, attempts=1):
        for attempt in range(attempts):
            try:
                result = subprocess.run(
                    ["gh", *args],
                    input=secret.encode("ascii") if secret is not None else b"",
                    capture_output=True,
                    timeout=20,
                    env=self.environment,
                    check=False,
                )
                if result.returncode == 0:
                    return result.stdout
            except (OSError, subprocess.TimeoutExpired):
                pass
            if attempt + 1 < attempts:
                time.sleep(2 ** attempt)
        raise RotationError(label)

    def metadata(self):
        secret = self.run(
            ["api", f"{BASE}/secrets/{SECRET}", "--jq", ".updated_at"],
            label="기존 Secret 메타데이터 조회 실패",
            attempts=3,
        )
        expiry = self.run(
            ["api", f"{BASE}/variables/{EXPIRY}", "--jq", ".value"],
            label="기존 만료일 변수 조회 실패",
            attempts=3,
        )
        try:
            return news.utc_time(secret.decode().strip()), news.utc_time(expiry.decode().strip())
        except (UnicodeError, TypeError, ValueError, news.NewsError):
            raise RotationError("기존 Secret 갱신 시각 또는 만료일 형식 오류") from None

    def write_secret(self, token):
        self.run(
            ["secret", "set", SECRET, "--repo", REPOSITORY],
            secret=token,
            label="갱신 Secret 저장 실패",
            attempts=3,
        )

    def write_expiry(self, expires):
        value = expires.isoformat().replace("+00:00", "Z")
        self.run(
            ["api", "--method", "PATCH", f"{BASE}/variables/{EXPIRY}", "-f", f"value={value}"],
            label="Secret 저장 후 만료일 갱신 실패",
            attempts=3,
        )


def verify_account(token, expected_id):
    try:
        expected = news.identifier(expected_id)
        profile = news.ThreadsClient(token, attempts=3).get("me", {"fields": "id,username"})
        matches = profile.get("id") == expected and profile.get("username") == news.EXPECTED_USERNAME
    except Exception:
        raise RotationError("Threads 계정 검증 요청 실패") from None
    require(matches, "Threads 운영 계정 ID 또는 이름 불일치")


def refresh(token, now):
    try:
        return news.request_token(token, endpoint="refresh_access_token", grant="th_refresh_token",
                                  started=now, transport=news.JsonTransport(attempts=3))
    except Exception:
        raise RotationError("Meta 장기 토큰 갱신 실패 또는 응답 검증 오류") from None


def rotate(repository, token, expected_id, recorded_expiry, *, verify_only=False):
    updated, expires = repository.metadata()
    require(expires == recorded_expiry, "실행 시작 이후 만료일 변경 감지")
    current = utc_now()
    require(current < expires, "Threads 토큰 만료. 운영 계정 재인증 필요")
    if verify_only:
        verify_account(token, expected_id)
        return "verify_only"

    if expires - current > timedelta(days=14):
        return "not_due"

    # Repository Secret changes are recent issue/refresh events and should age for at least a day.
    if current - updated < timedelta(days=1):
        return "recent_secret_update"

    verify_account(token, expected_id)
    replacement, new_expiry = refresh(token, current)
    require(new_expiry > expires, "갱신 응답이 현재 만료일을 연장하지 않음")
    verify_account(replacement, expected_id)
    require(repository.metadata() == (updated, expires), "갱신 중 운영 설정 변경 감지")
    repository.write_secret(replacement)
    repository.write_expiry(new_expiry)

    final_updated, final_expiry = repository.metadata()
    require(final_updated > updated and final_expiry == new_expiry, "두 저장 결과 재조회 불일치")
    return "rotated"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["due", "verify", "rotate"])
    mode = parser.parse_args().mode
    try:
        try:
            expires = news.utc_time(os.environ.get(EXPIRY, ""))
        except (TypeError, ValueError, news.NewsError):
            raise RotationError("기록된 UTC 만료일 형식 오류") from None

        remaining = expires - utc_now()
        require(remaining > timedelta(0), "Threads 토큰 만료. 운영 계정 재인증 필요")
        if mode == "due":
            print("true" if remaining <= timedelta(days=14) else "false")
            return 0

        require(os.environ.get("GITHUB_REPOSITORY") == REPOSITORY
                and os.environ.get("GITHUB_REF") == "refs/heads/main", "실행 저장소 또는 브랜치 불일치")
        try:
            require(bool(os.environ.get(SECRET)), "Threads Secret이 없습니다.")
            token = news.read_token()
        except news.NewsError:
            raise RotationError("Threads Secret 형식 오류") from None
        repository = Repository(os.environ.get("ROTATION_GITHUB_TOKEN"))
        result = rotate(repository, token, os.environ.get("THREADS_EXPECTED_USER_ID"), expires,
                        verify_only=mode == "verify")
        print(json.dumps({"rotation": result}))
        return 0
    except RotationError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    except Exception:
        # Avoid a traceback containing HTTP URLs, child output, or a response body.
        print("ERROR: Threads 갱신 중 예상하지 못한 오류", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
