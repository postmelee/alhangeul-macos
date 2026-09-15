#!/usr/bin/env python3
"""제품 소스와 격리한 로컬 소식 UI 검증 사이트를 생성한다. 공개 배포하지 않는다."""
import argparse
from pathlib import Path
import shutil

REPO = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).with_name('fixtures') / 'threads-news-ui'


def link(source, target):
    if target.is_symlink():
        if target.resolve() != source.resolve():
            raise ValueError('검증 경로의 링크 대상 불일치')
    elif not target.exists():
        target.symlink_to(source.resolve(), target_is_directory=source.is_dir())
    else:
        raise ValueError('검증 경로에 링크가 아닌 기존 파일이 있음')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-root', type=Path, required=True)
    parser.add_argument('--live-data', type=Path)
    args = parser.parse_args()
    root = args.output_root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    site = root / 'alhangeul-macos'
    site.mkdir(exist_ok=True)
    for source in (REPO / 'docs').iterdir():
        if source.name != 'data':
            link(source, site / source.name)
    (site / 'data').mkdir(exist_ok=True)
    shutil.copyfile(args.live_data or REPO / 'docs/data/news.json', site / 'data/news.json')
    shutil.copyfile(FIXTURES / 'bootstrap.js', root / 'test-bootstrap.js')
    shutil.copyfile(FIXTURES / 'runner.html', root / 'qa.html')
    for case in ['0', '1', '5', '6', '10', '11', 'inactive', 'expired', 'invalid',
                 'json-retry', 'script-retry', 'script-timeout', 'embed-retry', 'expires-open', 'expires-loading',
                 'no-observer', 'reduced']:
        case_root = root / 'cases' / case / 'alhangeul-macos'
        (case_root / 'news').mkdir(parents=True, exist_ok=True)
        for name in ['styles.css', 'news.js', 'assets']:
            link(REPO / 'docs' / name, case_root / name)
        html = (REPO / 'docs/news/index.html').read_text()
        for name in ['styles.css', 'news.js']:
            revision = (REPO / 'docs' / name).stat().st_mtime_ns
            html = html.replace(f'{name}?v=20260915-news', f'{name}?v={revision}')
            html = html.replace(f'{name}?v=20260915-manual', f'{name}?v={revision}')
        html = html.replace('</head>', f'<script src="../../../../test-bootstrap.js?case={case}"></script>\n</head>')
        (case_root / 'news/index.html').write_text(html)
    print('로컬 실제 소식·격리 fixture 검증 사이트 생성 완료')


if __name__ == '__main__':
    main()
