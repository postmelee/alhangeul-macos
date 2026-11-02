#!/usr/bin/env python3
"""#598 공급 진단. 새 출력 경로·격리 저장소·등록/인증서 없는 CLI만 사용한다."""
import argparse
import hashlib
import json
import platform
import os
import signal
import shutil
import subprocess
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def output_directory(value, root=ROOT):
    out = Path(value).resolve()
    base = root.resolve() / 'build.noindex'
    if out == base or not out.is_relative_to(base):
        raise ValueError('build.noindex 아래 새 하위 디렉터리가 필요합니다')
    # 파일·symlink·기존 결과 모두 덮어쓰지 않는다.
    out.mkdir(parents=True, exist_ok=False)
    return out


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command_text(args):
    return subprocess.check_output(args, cwd=ROOT, text=True, stderr=subprocess.STDOUT).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['fixtures', 'installed'], required=True)
    parser.add_argument('--family', default='')
    parser.add_argument('--output-dir', required=True)
    args = parser.parse_args()
    if args.mode == 'installed' and (not args.family.strip() or len(args.family.encode()) > 1024):
        parser.error('installed 모드는 1024 bytes 이하의 --family가 필요합니다')
    if args.mode == 'fixtures' and args.family:
        parser.error('--family는 installed 모드에서만 사용합니다')
    try:
        out = output_directory(args.output_dir)
    except (ValueError, OSError) as error:
        parser.error(str(error))
    result = {'schemaVersion': 1, 'runID': str(uuid.uuid4()), 'mode': args.mode,
              'evidenceKind': 'synthetic' if args.mode == 'fixtures' else 'installed-cli',
              'os': platform.mac_ver()[0], 'architecture': platform.machine(),
              'toolVersions': {'python': platform.python_version()}}
    state = out / 'private-state'
    code = 1
    phase = 'preflight'
    try:
        result['sourceCommit'] = command_text(['git', 'rev-parse', 'HEAD'])
        result['dirty'] = bool(command_text(['git', 'status', '--porcelain']))
        fixtures = ROOT / 'Tests/FontLibraryTests/Fixtures'
        fixture_hashes = {}
        for line in (fixtures / 'SHA256SUMS').read_text().splitlines():
            expected, name = line.split()
            actual = digest(fixtures / name)
            if actual != expected:
                raise ValueError('fixtureHashMismatch')
            fixture_hashes[name] = actual
        manifest = json.loads((ROOT / 'Sources/HostApp/Resources/rhwp-studio/manifest.json').read_text())
        receipt = json.loads((ROOT / 'Sources/Shared/FontLibrary/native-font-matcher-receipt.json').read_text())
        result['provenance'] = {'studioCommit': manifest['source_resolved_commit'],
                                'matcherCommit': receipt['commit'], 'fixtureHashes': fixture_hashes}
        lock = (ROOT / 'rhwp-core.lock').read_text()
        for line in lock.splitlines():
            if line.startswith('rhwp_commit = '):
                result['provenance']['coreCommit'] = line.split('"')[1]
        if len({result['provenance'][k] for k in ['coreCommit','studioCommit','matcherCommit']}) != 1:
            raise ValueError('provenanceMismatch')
        matcher = ROOT / 'Sources/Shared/FontLibrary/RhwpNativeFontMatcherSource.swift'
        if digest(matcher) != receipt['outputSHA256']:
            raise ValueError('matcherHashMismatch')
        sources = sorted((ROOT / 'Sources/Shared/FontLibrary').glob('*.swift'))
        sources += [ROOT / 'Sources/HostApp/Services/StudioFontSession.swift', ROOT / 'Tests/HFTFontSupplyProbe/main.swift']
        tracked = sources + [ROOT / 'Sources/HostApp/Services/StudioFontProviderScript.swift',
                             ROOT / 'scripts/ci/hft-font-supply-adapter.cjs', Path(__file__).resolve(),
                             ROOT / 'rhwp-core.lock', ROOT / 'Sources/HostApp/Resources/rhwp-studio/manifest.json',
                             ROOT / 'Sources/Shared/FontLibrary/native-font-matcher-receipt.json']
        result['provenance']['inputHashes'] = {str(p.relative_to(ROOT)): digest(p) for p in tracked}
        result['toolVersions'].update(node=command_text(['node','--version']), swift=command_text(['xcrun','swiftc','--version']))
        phase = 'compile'
        executable = out / 'hft-font-supply'
        command = ['xcrun','swiftc','-parse-as-library','-swift-version','5','-warnings-as-errors',
                   '-target',platform.machine()+'-apple-macosx12.0','-module-cache-path',str(out/'modules')]
        command += [str(p) for p in sources] + ['-o',str(executable)]
        with (out/'compile.log').open('w') as log:
            subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
        phase = 'supply'
        state.mkdir()
        process = subprocess.Popen(['node',str(ROOT/'scripts/ci/hft-font-supply-adapter.cjs'),str(ROOT),
                                    str(executable),str(state),args.mode,args.family], cwd=ROOT,
                                   stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True)
        try:
            stdout, _ = process.communicate(timeout=180)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate()
            raise
        # harness stderr 원문은 사용자 경로/전송 bytes 유출 방지를 위해 저장하지 않는다.
        payload = json.loads(stdout)
        if process.returncode not in (0,1,2) or 'cases' not in payload:
            raise ValueError('probeExecutionFailed')
        result.update(payload)
        code = process.returncode
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        result.update(error='probeExecutionFailed', failedPhase=phase)
        code = 1
    finally:
        if state.exists():
            shutil.rmtree(state)
        (out/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('공급 진단 결과:', out/'result.json')
    print('종료 코드:',code,'(0: 공급 검사 완료, 1: 실패, 2: 대상/환경 미확보; 문서 렌더 성공과 별개)')
    return code


if __name__ == '__main__':
    raise SystemExit(main())
