#!/usr/bin/env python3
"""고정된 배포 artifact의 출처·최초 설치 검증. 공개 배포는 수행하지 않는다."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
MAX_ARCHIVE = 2 * 1024**3

LIFECYCLE_REQUIRED = frozenset("""
deleted-original-documents
deleted-original-korean-word
modified-restored
modified-metadata
modified-old-word-removed
modified-new-word
modified-new-korean-word
modified-deleted-new-word
modified-deleted-new-korean-word
protected-restored
protected-metadata
protected-old-word-removed
empty-restored
empty-metadata
empty-old-word-removed
invalid-restored
invalid-metadata
invalid-old-word-removed
drm-restored
drm-metadata
drm-old-word-removed
distribution-restored
distribution-metadata
distribution-old-word-removed
large-restored
large-metadata
large-old-word-removed
truncated-metadata
truncated-prefix-search
truncated-korean-prefix-search
truncated-tail-not-indexed
deleted-truncated-document
deleted-final-documents
""".split())


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts/ci' / filename)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def identity(env):
    patterns = {'SOURCE_RUN_ID': r'[1-9][0-9]*', 'SOURCE_ARTIFACT_ID': r'[1-9][0-9]*',
                'SOURCE_SHA': r'[0-9a-f]{40}', 'DMG_SHA256': r'[0-9a-f]{64}',
                'EXPECTED_VERSION': r'[0-9]+\.[0-9]+\.[0-9]+', 'EXPECTED_BUILD': r'[1-9][0-9]*'}
    result = {}
    for key, pattern in patterns.items():
        value = env.get(key, '')
        if not re.fullmatch(pattern, value):
            raise ValueError(f'잘못된 필수 입력: {key}')
        result[key.lower()] = value
    repo = env.get('GITHUB_REPOSITORY', '')
    if repo != 'postmelee/alhangeul-macos':
        raise ValueError('원본 저장소에서만 배포 후보 검증을 실행할 수 있음')
    result['repository'] = repo
    return result


def validate_origin(candidate, run, artifact):
    if (str(run.get('id')) != candidate['source_run_id']
            or run.get('head_sha') != candidate['source_sha']
            or run.get('head_repository', {}).get('full_name') != candidate['repository']
            or run.get('repository', {}).get('full_name') != candidate['repository']
            or run.get('path') != '.github/workflows/release-publish.yml'
            or run.get('event') != 'workflow_dispatch'
            or run.get('status') != 'completed' or run.get('conclusion') != 'success'):
        raise ValueError('성공한 원본 release-publish 실행 및 소스 SHA와 불일치')
    if (str(artifact.get('id')) != candidate['source_artifact_id']
            or artifact.get('workflow_run', {}).get('id') != run['id']
            or artifact.get('workflow_run', {}).get('head_sha') != candidate['source_sha']
            or artifact.get('expired') is not False
            or artifact.get('name') != f"alhangeul-macos-{candidate['expected_version']}-public-dmg"
            or not 0 < artifact.get('size_in_bytes', 0) <= MAX_ARCHIVE):
        raise ValueError('artifact 출처·이름·크기·만료 상태 불일치')


def extract_archive(archive, output, version):
    expected = f'alhangeul-macos-{version}.dmg'
    allowed_names = {expected, expected + '.sha256', f'release-notes-{version}.md'}
    if archive.stat().st_size > MAX_ARCHIVE:
        raise ValueError('archive 크기 초과')
    with zipfile.ZipFile(archive) as z:
        entries = z.infolist()
        names = [e.filename for e in entries]
        if (len(names) != len(set(names)) or names.count(expected) != 1
                or sum(e.file_size for e in entries) > MAX_ARCHIVE):
            raise ValueError('archive 중복·DMG 누락·크기 초과')
        for entry in entries:
            p = Path(entry.filename)
            mode = entry.external_attr >> 16
            if (p.name != entry.filename or entry.is_dir() or stat.S_ISLNK(mode)
                    or entry.filename not in allowed_names):
                raise ValueError('허용하지 않은 archive 경로/형식')
        if output.exists():
            raise ValueError('추출 경로가 이미 있음')
        output.mkdir()
        z.extractall(output)
    return output / expected


def fetch(output, candidate):
    def api(endpoint):
        return json.loads(subprocess.check_output(['gh', 'api', endpoint], timeout=60))
    base = f"repos/{candidate['repository']}/actions"
    run = api(f"{base}/runs/{candidate['source_run_id']}")
    artifact = api(f"{base}/artifacts/{candidate['source_artifact_id']}")
    validate_origin(candidate, run, artifact)
    (output / 'origin.json').write_text(json.dumps({'candidate': candidate, 'run': run, 'artifact': artifact}, indent=2))
    archive = output / 'candidate.zip'
    with archive.open('xb') as stream:
        subprocess.run(['gh', 'api', f"{base}/artifacts/{candidate['source_artifact_id']}/zip"],
                       stdout=stream, check=True, timeout=300)
    dmg = extract_archive(archive, output / 'download', candidate['expected_version'])
    if sha256(dmg) != candidate['dmg_sha256']:
        raise ValueError('DMG SHA256 불일치')
    archive.unlink()


def require_complete(first, stopped, final):
    for state in (first, stopped):
        if (state.get('launch_count') != 1 or state.get('assisted_actions')
                or state.get('phase') != 'searchable'
                or state.get('before_install_paths')
                or not state.get('pre_install_environment_verified')):
            raise ValueError('일반 최초 실행 수용 조건 누락')
        cases = {r['case'] for r in state.get('results', []) if r['result'] == 'PASS'}
        if not {'automatic-first-install-search', 'body-only-search', 'korean-body-only-search'} <= cases:
            raise ValueError('필수 검색 증거 누락')
    if not any(r['case'] == 'candidate-app-not-running' and r['result'] == 'PASS'
               for r in stopped.get('results', [])):
        raise ValueError('앱 종료 후 검색 증거 누락')
    if (final.get('phase') != 'cleaned' or not final.get('cleanup_index_verified')
            or final.get('assisted_actions') != ['lifecycle']):
        raise ValueError('lifecycle/정리 완료 조건 누락')
    if any(r['result'] == 'FAIL' for r in final.get('results', [])):
        raise ValueError('중간 실패가 있어 후보 전체 PASS로 판정하지 않음')
    allowed_miss = {'discovery-before-first-launch'}
    if any(r['result'] != 'PASS' and r['case'] not in allowed_miss for r in final.get('results', [])):
        raise ValueError('미실행/발견 실패가 남음')
    cases = {r['case'] for r in final['results']}
    if not (LIFECYCLE_REQUIRED | {'cleanup-importer-catalog'}) <= cases:
        raise ValueError('필수 lifecycle/정리 증거 누락')


def verify(output, candidate, fixtures, result):
    probe = module('install_probe', 'install-environment-probe.py')
    env = probe.probe()
    (output / 'environment.json').write_text(json.dumps(env, ensure_ascii=False, indent=2))
    result['environment'] = {k: v for k, v in env.items() if k != 'commands'}
    if env['status'] != 'ENVIRONMENT_READY':
        result['status'] = env['status']
        raise RuntimeError('검증 VM의 설치 전제 불충족')
    origin = json.loads((output / 'origin.json').read_text())
    if origin['candidate'] != candidate:
        raise ValueError('다운로드 단계와 현재 후보 입력 불일치')
    validate_origin(candidate, origin['run'], origin['artifact'])
    dmg = output / 'download' / f"alhangeul-macos-{candidate['expected_version']}.dmg"
    if sha256(dmg) != candidate['dmg_sha256']:
        raise ValueError('다운로드 후 DMG SHA256 변경')
    smoke = module('system_smoke', 'spotlight-system-smoke.py')
    mount = output / 'mount'
    mount.mkdir()
    mounted = False
    state_path = output / 'state.json'
    counter = 0

    def run(argv, timeout=60):
        nonlocal counter
        counter += 1
        return smoke.run(argv, output / f'command-{counter:02d}.log', timeout=timeout)

    try:
        run(['xcrun', 'stapler', 'validate', str(dmg)])
        run(['spctl', '--assess', '--type', 'open', '--context', 'context:primary-signature', '--verbose', str(dmg)])
        run(['hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', str(mount), str(dmg)])
        mounted = True
        app = mount / 'Alhangeul.app'
        if app.is_symlink() or not app.is_dir():
            raise ValueError('DMG 최상위 Alhangeul.app 누락 또는 symlink')
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        if (info.get('CFBundleShortVersionString') != candidate['expected_version']
                or str(info.get('CFBundleVersion')) != candidate['expected_build']
                or info.get('CFBundleIdentifier') != 'com.postmelee.alhangeul'):
            raise ValueError('앱 버전·빌드·bundle ID 불일치')
        run(['codesign', '--verify', '--deep', '--strict', str(app)])
        signature = run(['codesign', '-dv', '--verbose=4', str(app)])
        if 'Authority=Developer ID Application:' not in signature:
            raise ValueError('Developer ID 배포 서명이 아님')
        run(['xcrun', 'stapler', 'validate', str(app)])
        run(['spctl', '--assess', '--type', 'execute', '--verbose', str(app)])
        run(['bash', str(ROOT / 'scripts/ci/verify-universal-macos-app.sh'), str(app)])
        staging = output / 'source.noindex' / 'Alhangeul.app'
        staging.parent.mkdir()
        run(['ditto', str(app), str(staging)], timeout=120)
        run(['hdiutil', 'detach', str(mount)])
        mounted = False
        app = staging
        manifest = json.loads((fixtures / 'manifest.json').read_text())
        args = argparse.Namespace(app=app, fixtures=fixtures, token=manifest['token'], state=state_path,
                                  automatic=True, install_layout='direct', discovery_timeout=600, search_timeout=180)
        smoke.prepare(args)
        state = json.loads(state_path.read_text())
        try:
            for phase in ('environment', 'install', 'launch', 'automatic_search', 'stop_candidate', 'automatic_search'):
                getattr(smoke, phase)(state)
                smoke.save(state_path, state)
                if phase == 'automatic_search':
                    target = 'first-launch.json' if not (output / 'first-launch.json').exists() else 'stopped-search.json'
                    smoke.save(output / target, state)
            state.setdefault('assisted_actions', []).append('lifecycle')
            smoke.lifecycle(state)
            smoke.save(output / 'lifecycle.json', state)
        finally:
            smoke.save(state_path, state)
    finally:
        try:
            if state_path.exists():
                state = json.loads(state_path.read_text())
                if state.get('index_environment') == 'unavailable':
                    result['status'] = 'ENVIRONMENT_UNAVAILABLE'
                try:
                    smoke.owned_locations(state)
                    smoke.cleanup(state)
                except Exception as error:
                    result['cleanup_error'] = str(error)
                    result['status'] = 'HARNESS_ERROR'
                    raise
                finally:
                    smoke.save(state_path, state)
        finally:
            if mounted:
                run(['hdiutil', 'detach', str(mount)])
    first = json.loads((output / 'first-launch.json').read_text())
    stopped = json.loads((output / 'stopped-search.json').read_text())
    final = json.loads(state_path.read_text())
    require_complete(first, stopped, final)
    result.update(status='PASS', release_eligible=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['fetch', 'verify'])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--fixtures', type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    result = {'schema_version': 1, 'status': 'CANDIDATE_FAILED', 'release_eligible': False,
              'phase': args.phase, 'harness_sha': os.environ.get('GITHUB_SHA'),
              'run_id': os.environ.get('GITHUB_RUN_ID'), 'run_attempt': os.environ.get('GITHUB_RUN_ATTEMPT')}
    started = time.monotonic()
    try:
        candidate = identity(os.environ)
        result['candidate'] = candidate
        if args.phase == 'fetch':
            fetch(output, candidate)
            result['status'] = 'CANDIDATE_DOWNLOADED'
        else:
            if (os.environ.get('GITHUB_ACTIONS') != 'true'
                    or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted'):
                raise ValueError('새 GitHub-hosted VM에서만 설치 검증 허용')
            if os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN'):
                raise ValueError('앱 실행 단계에 GitHub token을 전달하지 말 것')
            if not args.fixtures:
                raise ValueError('--fixtures 누락')
            verify(output, candidate, args.fixtures.resolve(), result)
    except Exception as error:
        result['reason'] = str(error)
        if isinstance(error, (OSError, subprocess.SubprocessError)):
            result['status'] = 'HARNESS_ERROR'
    finally:
        result['elapsed_seconds'] = round(time.monotonic()-started, 2)
        (output / f'{args.phase}-result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['status'] in ('PASS', 'CANDIDATE_DOWNLOADED') else 1


if __name__ == '__main__':
    raise SystemExit(main())
