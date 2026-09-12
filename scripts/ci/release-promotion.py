#!/usr/bin/env python3
"""두 새 VM의 검증 증거와 기존 Release 자산을 대조한다. 빌드/업로드하지 않는다."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import zipfile

spec = importlib.util.spec_from_file_location('install_smoke', Path(__file__).with_name('release-install-smoke.py'))
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)
RUNNERS = {'macos-15': 'arm64', 'macos-15-intel': 'x86_64'}
EVIDENCE_FILES = {'verify-result.json', 'first-launch.json', 'stopped-search.json', 'state.json'}
MAX_EVIDENCE = 64 * 1024**2


def api(endpoint):
    return json.loads(subprocess.check_output(['gh', 'api', endpoint], timeout=60))


def download(endpoint, path, limit, accept=None):
    args = ['gh', 'api', endpoint]
    if accept:
        args += ['-H', f'Accept: {accept}']
    with path.open('xb') as stream:
        subprocess.run(args, stdout=stream, check=True, timeout=300)
    if not 0 < path.stat().st_size <= limit:
        raise ValueError('다운로드 파일 크기 초과 또는 빈 파일')


def validate_run(candidate, run, run_id):
    if (str(run.get('id')) != run_id or run.get('head_sha') != candidate['source_sha']
            or run.get('repository', {}).get('full_name') != candidate['repository']
            or run.get('head_repository', {}).get('full_name') != candidate['repository']
            or run.get('path') != '.github/workflows/release-first-install.yml'
            or run.get('event') != 'workflow_dispatch'
            or run.get('status') != 'completed' or run.get('conclusion') != 'success'
            or type(run.get('run_attempt')) is not int or run['run_attempt'] < 1):
        raise ValueError('같은 tag SHA의 성공한 최초 설치 실행이 아님')


def validate_evidence_artifact(candidate, run, artifact, runner):
    expected = f"first-install-evidence-{runner}-{run['id']}-{run['run_attempt']}"
    if (artifact.get('name') != expected or artifact.get('expired') is not False
            or artifact.get('workflow_run', {}).get('id') != run['id']
            or artifact.get('workflow_run', {}).get('head_sha') != candidate['source_sha']
            or not 0 < artifact.get('size_in_bytes', 0) <= MAX_EVIDENCE):
        raise ValueError('최신 검증 회차의 증거 artifact가 아님')


def read_evidence(archive):
    # 로그 등은 추출하지 않는다. 필수 JSON은 archive root의 파일만 인정한다.
    with zipfile.ZipFile(archive) as z:
        entries = z.infolist()
        names = [e.filename for e in entries]
        if (len(names) != len(set(names)) or not EVIDENCE_FILES <= set(names)
                or sum(e.file_size for e in entries) > MAX_EVIDENCE):
            raise ValueError('증거 누락·중복·크기 초과')
        for entry in entries:
            path = Path(entry.filename)
            if path.is_absolute() or '..' in path.parts or stat.S_ISLNK(entry.external_attr >> 16):
                raise ValueError('허용하지 않은 증거 경로/형식')
        return {name: json.loads(z.read(name)) for name in EVIDENCE_FILES}


def validate_evidence(candidate, run, runner, evidence):
    result = evidence['verify-result.json']
    env = result.get('environment', {})
    if (result.get('schema_version') != 1 or result.get('status') != 'PASS'
            or result.get('release_eligible') is not True or result.get('phase') != 'verify'
            or result.get('candidate') != candidate or result.get('harness_sha') != candidate['source_sha']
            or str(result.get('run_id')) != str(run['id'])
            or str(result.get('run_attempt')) != str(run['run_attempt'])
            or env.get('status') != 'ENVIRONMENT_READY'
            or env.get('architecture') != RUNNERS[runner]):
        raise ValueError('후보 identity·최신 회차·아키텍처·PASS 불일치')
    smoke.require_complete(evidence['first-launch.json'], evidence['stopped-search.json'], evidence['state.json'])


def release_assets(candidate, release):
    if (release.get('tag_name') != 'v' + candidate['expected_version']
            or release.get('prerelease') is not False or type(release.get('draft')) is not bool):
        raise ValueError('stable 승격 대상 Release 상태 불일치')
    name = f"alhangeul-macos-{candidate['expected_version']}.dmg"
    selected = {}
    for required in (name, name + '.sha256'):
        matches = [a for a in release.get('assets', []) if a.get('name') == required]
        if len(matches) != 1 or matches[0].get('state') != 'uploaded':
            raise ValueError('Release DMG/checksum 누락 또는 중복')
        asset = matches[0]
        limit = smoke.MAX_ARCHIVE if required == name else 4096
        if not 0 < asset.get('size', 0) <= limit:
            raise ValueError('Release 자산 크기 초과 또는 빈 파일')
        selected[required] = asset
    return selected


def asset_identity(candidate, release):
    return {name: {key: asset.get(key) for key in ('id', 'name', 'size', 'state', 'digest', 'created_at', 'updated_at')}
            for name, asset in release_assets(candidate, release).items()}


def verify_bytes(candidate, dmg, checksum):
    name = f"alhangeul-macos-{candidate['expected_version']}.dmg"
    if smoke.sha256(dmg) != candidate['dmg_sha256']:
        raise ValueError('Release DMG가 검증된 후보와 다름')
    if not re.fullmatch(re.escape(candidate['dmg_sha256']) + r' [ *]' + re.escape(name) + r'\n?',
                        checksum.read_text()):
        raise ValueError('공개 checksum과 DMG hash/이름 불일치')


def version_tuple(tag):
    if not re.fullmatch(r'v[0-9]+\.[0-9]+\.[0-9]+', tag):
        raise ValueError('latest stable 버전을 해석할 수 없음')
    return tuple(int(p) for p in tag[1:].split('.'))


def check_latest(candidate, latest):
    if version_tuple(latest['tag_name']) > version_tuple('v' + candidate['expected_version']):
        raise ValueError('더 새 공개 버전이 있어 이전 appcast로 되돌릴 수 없음')


def verify_release(candidate, output):
    base = f"repos/{candidate['repository']}"
    release = api(f"{base}/releases/tags/v{candidate['expected_version']}")
    check_latest(candidate, api(f'{base}/releases/latest'))
    assets = release_assets(candidate, release)
    for name, asset in assets.items():
        download(f"{base}/releases/assets/{asset['id']}", output / name,
                 smoke.MAX_ARCHIVE if name.endswith('.dmg') else 4096, 'application/octet-stream')
        if (output / name).stat().st_size != asset['size']:
            raise ValueError('Release 자산 길이 불일치')
    name = f"alhangeul-macos-{candidate['expected_version']}.dmg"
    verify_bytes(candidate, output / name, output / (name + '.sha256'))
    return release


def validate_all(candidate, run_id, output):
    base = f"repos/{candidate['repository']}/actions"
    run = api(f'{base}/runs/{run_id}')
    validate_run(candidate, run, run_id)
    # --paginate --slurp preserves all pages; a rerun can leave prior-attempt artifacts.
    pages = json.loads(subprocess.check_output(
        ['gh', 'api', '--paginate', '--slurp', f'{base}/runs/{run_id}/artifacts?per_page=100'], timeout=60))
    artifacts = [a for page in pages for a in page['artifacts']]
    selected = []
    for runner in RUNNERS:
        name = f"first-install-evidence-{runner}-{run_id}-{run['run_attempt']}"
        matches = [a for a in artifacts if a.get('name') == name]
        if len(matches) != 1:
            raise ValueError(f'{runner} 최신 회차 증거 없음/중복')
        # Listing payloads need not include workflow_run. Fetch authoritative metadata.
        artifact = api(f"{base}/artifacts/{matches[0]['id']}")
        validate_evidence_artifact(candidate, run, artifact, runner)
        archive = output / f'{runner}.zip'
        download(f"{base}/artifacts/{artifact['id']}/zip", archive, MAX_EVIDENCE)
        evidence = read_evidence(archive)
        validate_evidence(candidate, run, runner, evidence)
        (output / f'{runner}.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2))
        archive.unlink()
        selected.append(artifact)
    return {'run': run, 'artifacts': selected}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['verify', 'publish'])
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    candidate = smoke.identity(os.environ)
    run_id = os.environ.get('VALIDATION_RUN_ID', '')
    if not re.fullmatch(r'[1-9][0-9]*', run_id):
        raise ValueError('VALIDATION_RUN_ID 필수')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    phase = output / args.phase
    phase.mkdir()  # 같은 로컬 증거 디렉터리 재사용 거부
    if args.phase == 'verify':
        smoke.fetch(phase, candidate)
        validation = validate_all(candidate, run_id, phase)
        release = verify_release(candidate, phase)
        proof = {'candidate': candidate, 'validation': validation, 'release': release}
        (output / 'promotion-proof.json').write_text(json.dumps(proof, ensure_ascii=False, indent=2))
    else:
        proof = json.loads((output / 'promotion-proof.json').read_text())
        if proof['candidate'] != candidate or str(proof['validation']['run']['id']) != run_id:
            raise ValueError('승격 직전 입력 변경')
        # Pages 준비 중 rerun/자산 교체/tag 이동이 발생했는지 다시 확인한다.
        run = api(f"repos/{candidate['repository']}/actions/runs/{run_id}")
        validate_run(candidate, run, run_id)
        if run['run_attempt'] != proof['validation']['run']['run_attempt']:
            raise ValueError('검증 run이 재실행됨; 전체 승격 검증을 다시 실행할 것')
        for artifact in proof['validation']['artifacts']:
            current = api(f"repos/{candidate['repository']}/actions/artifacts/{artifact['id']}")
            if current.get('expired') is not False:
                raise ValueError('검증 증거 만료')
        release = verify_release(candidate, phase)
        if release['id'] != proof['release']['id'] or asset_identity(candidate, release) != asset_identity(candidate, proof['release']):
            raise ValueError('승격 준비 후 Release 자산이 변경됨')
        if release['draft']:
            subprocess.run(['gh', 'release', 'edit', 'v' + candidate['expected_version'],
                            '--repo', candidate['repository'], '--draft=false', '--prerelease=false', '--latest',
                            '--verify-tag'], check=True, timeout=60)
        # 공개 후 재실행은 같은 자산을 확인한 뒤 Pages 복구만 허용한다.
        published = api(f"repos/{candidate['repository']}/releases/tags/v{candidate['expected_version']}")
        if published['draft'] or published['prerelease'] or asset_identity(candidate, published) != asset_identity(candidate, release):
            raise ValueError('공개 후 Release 상태/자산 불일치')
        (output / 'published-release.json').write_text(json.dumps(published, indent=2))
    print(f'{args.phase}: verified DMG {candidate["dmg_sha256"]}')


if __name__ == '__main__':
    main()
