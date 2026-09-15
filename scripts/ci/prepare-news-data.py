#!/usr/bin/env python3
"""새 자동 수집 또는 명시된 수동 목록을 Pages에 전달한다."""
import argparse
from datetime import datetime, timedelta, timezone
import importlib.util
import json
import os
from pathlib import Path
import sys

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('threads_news', Path(__file__).with_name('threads-news.py'))
news = importlib.util.module_from_spec(spec)
spec.loader.exec_module(news)
SEED = {'schema_version': 2, 'updated_at': None, 'expires_at': None, 'items': []}


def enabled(value):
    news.require(value in ('', 'false', 'true'), 'THREADS_NEWS_ENABLED는 true/false 또는 미설정만 허용')
    return value == 'true'


def manual_data(source):
    return news.validate_manual_news(news.read_json(source)) if source else SEED.copy()


def prepare(active, source=None, *, now=None, manual_input=None):
    data = news.read_json(source) if source else SEED.copy()
    if active:
        news.validate_news(data)
        news.require(source is not None and data['updated_at'] is not None, '활성 소식은 이번 실행의 snapshot 필요')
        current = now or datetime.now(timezone.utc)
        updated, expires = news.utc_time(data['updated_at']), news.utc_time(data['expires_at'])
        news.require(current - timedelta(minutes=15) <= updated <= current + timedelta(minutes=5),
                     '이번 실행에서 15분 이내에 수집한 snapshot 필요')
        news.require(expires > current, '소식 snapshot 만료')
    else:
        expected = manual_data(manual_input)
        if source is None:
            data = expected
        news.require(data == expected, '소식 입력이 현재 수동 목록 또는 빈 초기값과 다름')
    return data


def collect(active, output, *, environment=os.environ, manual_input=None):
    if not active:
        data = manual_data(manual_input)
        news.atomic_write(output, (json.dumps(data, indent=2) + '\n').encode())
        return {'status': 'manual' if manual_input else 'disabled',
                'item_count': len(data['items']), 'updated_at': None}
    # read_token의 대화형 입력 경로를 CI에서 사용하지 않는다.
    token = environment.get('THREADS_ACCESS_TOKEN', '').strip()
    news.require(bool(token), 'Threads 토큰 미설정')
    account = environment.get('THREADS_EXPECTED_USER_ID', '')
    expiry = environment.get('THREADS_TOKEN_EXPIRES_AT', '')
    news.identifier(account)
    news.require(news.token_status(expiry)['status'] in {'valid', 'renewal_due'}, '유효한 토큰 만료 시각 필요')
    excluded = news.parse_json(environment.get('THREADS_NEWS_EXCLUDED_URLS', '[]') or '[]')
    return news.sync(news.ThreadsClient(token, attempts=3, deadline_seconds=300),
                     news.OEmbedClient(attempts=3, deadline_seconds=300),
                     expected_user_id=account, expires_at=expiry, excluded_urls=excluded,
                     token=token, output=output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['collect', 'prepare'])
    parser.add_argument('--enabled', default=os.environ.get('THREADS_NEWS_ENABLED', ''))
    parser.add_argument('--input', type=Path)
    parser.add_argument('--manual-input', type=Path, help='자동 비활성 시 사용할 운영자 선택 목록')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        active = enabled(args.enabled)
        news.require(args.output.suffix == '.json', '출력은 .json 파일 필요')
        news.require(args.command != 'collect' or args.input is None, '수집에는 이전 snapshot 입력 금지')
        if args.command == 'collect':
            summary = collect(active, args.output, manual_input=args.manual_input)
        else:
            data = prepare(active, args.input, manual_input=args.manual_input)
            news.atomic_write(args.output, (json.dumps(data, ensure_ascii=False, indent=2) + '\n').encode())
            summary = {'status': 'prepared', 'item_count': len(data['items']), 'updated_at': data.get('updated_at')}
        print(json.dumps(summary, ensure_ascii=False))
        if summary.get('token', {}).get('renewal_required'):
            print('::warning::Threads 토큰이 14일 이내에 만료됩니다. 수동 갱신이 필요합니다.', file=sys.stderr)
        return 0
    except (news.NewsError, OSError, ValueError):
        print('ERROR: 소식 준비 실패. 활성 상태·토큰 만료·수집 결과를 확인하세요. 기존 배포를 유지합니다.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
