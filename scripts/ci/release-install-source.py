#!/usr/bin/env python3
"""불변 DMG 후보와 검토된 설치 검증 도구의 Git 출처를 대조한다."""
import plistlib
import re
import subprocess

# 제품/의존성/fixture 생성기와 임의 실행 스크립트 변경을 허용하지 않는다.
TOOL_FILES = {
    '.github/workflows/release-first-install.yml', '.github/workflows/release-promote.yml',
    'scripts/ci/release-install-source.py', 'scripts/ci/release-install-smoke.py',
    'scripts/ci/spotlight-system-smoke.py', 'scripts/ci/release-promotion.py',
    'scripts/ci/test-release-install-smoke.py', 'scripts/ci/test-spotlight-system-smoke.py',
    'scripts/ci/test-release-promotion.py',
}


def prove(candidate, workflow_ref, harness_sha, root=None, checkout=False):
    tag = 'v' + candidate['expected_version']
    source = candidate['source_sha']
    if (not re.fullmatch(r'[0-9a-f]{40}', source)
            or not re.fullmatch(r'[0-9a-f]{40}', harness_sha)
            or not re.fullmatch(r'v[0-9]+\.[0-9]+\.[0-9]+', tag)
            or workflow_ref not in ('refs/heads/main', 'refs/tags/' + tag)):
        raise ValueError('설치 검증은 정확한 후보 tag 또는 검토된 main에서만 허용')

    def git(*args):
        return subprocess.check_output(['git', *args], cwd=root, timeout=60).decode().rstrip('\n')

    if checkout:
        if git('rev-parse', 'HEAD') != harness_sha or git('status', '--porcelain', '--untracked-files=all'):
            raise ValueError('설치 검증 checkout SHA 불일치 또는 기록되지 않은 변경')
    if git('rev-parse', f'refs/tags/{tag}^{{commit}}') != source:
        raise ValueError('설치 후보 tag와 source SHA 불일치')
    if workflow_ref.startswith('refs/tags/') and harness_sha != source:
        raise ValueError('tag의 검증 도구 SHA가 후보와 다름')
    git('merge-base', '--is-ancestor', source, harness_sha)
    # API의 branch 이름만 신뢰하지 않고 현재 main의 이력에 속하는지 재검사한다.
    git('merge-base', '--is-ancestor', harness_sha, 'refs/remotes/origin/main')
    paths = [p for p in git('diff', '--no-renames', '--name-only', '-z', source, harness_sha).split('\0') if p]
    if any(path not in TOOL_FILES and not path.startswith('mydocs/') for path in paths):
        raise ValueError('후보 이후 제품·fixture·의존성 또는 허용하지 않은 도구 변경')
    for name in ('HostApp', 'QLExtension', 'ThumbnailExtension', 'SpotlightImporter'):
        data = subprocess.check_output(['git', 'show', f'{source}:Sources/{name}/Info.plist'], cwd=root, timeout=60)
        info = plistlib.loads(data)
        if (info.get('CFBundleShortVersionString') != candidate['expected_version']
                or str(info.get('CFBundleVersion')) != candidate['expected_build']):
            raise ValueError('설치 후보 bundle version/build 불일치')
    return {'schema_version': 1, 'candidate_sha': source, 'harness_sha': harness_sha,
            'workflow_ref': workflow_ref, 'fixture_source_sha': source, 'tooling_only_changes': paths}
