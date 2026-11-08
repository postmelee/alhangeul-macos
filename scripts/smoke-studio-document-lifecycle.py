#!/usr/bin/env python3
"""실제 SwiftUI/Studio 문서 전환·저장·종료 통합 smoke (로그인한 macOS 필요)."""
import argparse
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import platform
import sys
import hashlib
import json
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture', type=pathlib.Path, required=True, help='읽기 전용 HWP/HWPX 입력')
    parser.add_argument('--command-failures', action='store_true', help='합성 오류 계약의 native 수신·세션 보존 검사 (upstream rollback 검증 아님)')
    parser.add_argument('--fatal-recovery', action='store_true', help='치명적 오류·이전 저장본·재시작 native 통합 검사')
    parser.add_argument('--integration', action='store_true', help='실제 JS 오류·초기화 실패·진단 UI·반복 로드·창 독립성 검사')
    parser.add_argument('--output-root', type=pathlib.Path, help='검증 산출물 루트 (외장 build.noindex)')
    parser.add_argument('--studio-resources', type=pathlib.Path, help='검증 전용 실제 Studio 번들')
    parser.add_argument('--upstream-recovery', action='store_true', help='공개 API의 실제 rollback WKWebView 검사')
    parser.add_argument('--stall-web-fonts', action='store_true', help='복구 통합 검사에서 외부 FontFace 응답 무한 지연 주입')
    args = parser.parse_args()
    if args.stall_web_fonts and not args.upstream_recovery:
        parser.error('--stall-web-fonts는 --upstream-recovery 전용입니다.')
    if sum((args.command_failures, args.fatal_recovery, args.integration, args.upstream_recovery)) > 1:
        parser.error('검사 모드는 하나만 선택하세요.')
    root = pathlib.Path(__file__).resolve().parent.parent
    fixture = args.fixture.resolve(strict=True)
    # 정상 생명주기 입력이다. 확장자만 .hwpx인 HWP5 샘플을 HWPX 수용 근거로 쓰지 않는다.
    if fixture.suffix.lower() == '.hwpx':
        try:
            with zipfile.ZipFile(fixture) as archive:
                if archive.read('mimetype').strip() != b'application/hwp+zip':
                    parser.error('HWPX fixture의 mimetype이 application/hwp+zip이 아닙니다.')
        except (zipfile.BadZipFile, KeyError):
            parser.error('HWPX fixture는 실제 ZIP/HWPX 문서여야 합니다. 확장자만으로 판정하지 않습니다.')
    build = args.output_root.resolve() if args.output_root else root / 'build.noindex'
    if args.output_root and (not pathlib.Path('/Volumes/T7').is_dir() or not build.is_relative_to('/Volumes/T7')):
        parser.error('외장 검증은 연결된 /Volumes/T7 아래에서 실행해야 합니다.')
    build.mkdir(exist_ok=True, parents=True)
    prefix = 'task594-integration-' if args.integration else ('studio-fatal-recovery-' if args.fatal_recovery else ('studio-command-failure-' if args.command_failures else 'studio-lifecycle-'))
    output = pathlib.Path(tempfile.mkdtemp(prefix=prefix, dir=build))
    app = output / 'StudioLifecycleSmoke.app'
    executable = app / 'Contents/MacOS/StudioLifecycleSmoke'
    executable.parent.mkdir(parents=True)
    resources = app / 'Contents/Resources'
    resources.mkdir()
    shutil.copytree(args.studio_resources or root / 'Sources/HostApp/Resources/rhwp-studio', resources / 'rhwp-studio')
    if args.studio_resources:
        shutil.copy2(root / 'Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css', resources / 'rhwp-studio/alhangeul-wkwebview-overrides.css')
    if args.stall_web_fonts:
        index = resources / 'rhwp-studio/index.html'
        html = index.read_text()
        if html.count('<head>') != 1:
            parser.error('진단 스크립트 삽입 head가 유일하지 않습니다.')
        injection = (root / 'scripts/ci/studio-web-font-stall.js').read_text()
        index.write_text(html.replace('<head>', '<head><script>' + injection + '</script>'))
    # 독립 preferences/draft 저장소를 사용한다. 사용자 앱 bundle ID를 재사용하지 않는다.
    info = {'CFBundleIdentifier': 'com.postmelee.studio-lifecycle.' + output.name,
            'CFBundleExecutable': executable.name, 'CFBundleName': 'StudioLifecycleSmoke',
            'CFBundlePackageType': 'APPL'}
    product_info = plistlib.loads((root / 'Sources/HostApp/Info.plist').read_bytes())
    for key in ('CFBundleShortVersionString', 'CFBundleVersion'):
        info[key] = product_info[key]
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    sources = [p for directory in ('Sources/HostApp', 'Sources/Shared', 'Sources/RhwpCoreBridge')
               for p in sorted((root / directory).rglob('*.swift'))
               if p.name not in ('HostApp.swift', 'UpdateController.swift')]
    bridge = root / 'Frameworks/Rhwp.xcframework/macos-arm64_x86_64'
    arch = 'arm64' if platform.machine() == 'arm64' else 'x86_64'
    command = ['xcrun', 'swiftc', '-parse-as-library', '-swift-version', '5',
               '-target', arch + '-apple-macosx12.0', '-module-cache-path', str(build / 'studio-smoke-module-cache'),
               '-I', str(bridge / 'Headers'), '-L', str(bridge), '-lrhwp', '-lc++', '-liconv', '-lz']
    for framework in ('AppKit', 'WebKit', 'SwiftUI', 'CoreFoundation', 'CoreText', 'CoreGraphics',
                      'ImageIO', 'CoreServices', 'Network', 'ApplicationServices', 'Security',
                      'Metal', 'QuartzCore', 'IOSurface', 'ColorSync'):
        command += ['-framework', framework]
    command += [str(p) for p in sources]
    test_main = 'StudioUpstreamRecoverySmoke' if args.upstream_recovery else 'StudioErrorRecoveryIntegrationSmoke' if args.integration else ('StudioFatalRecoverySmoke' if args.fatal_recovery else ('StudioCommandFailureSmoke' if args.command_failures else 'StudioDocumentLifecycleSmoke'))
    command += [str(root / 'Tests' / test_main / 'main.swift'), '-o', str(executable)]
    print('Evidence:', output, flush=True)
    with (output / 'build.log').open('w') as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=300)
    # 파일/상태를 보존하고 해당 실행 소유 앱의 LaunchServices 등록만 해제한다.
    before_hash = hashlib.sha256(fixture.read_bytes()).hexdigest()
    try:
        with (output / 'run.log').open('w') as log:
            result = subprocess.run([str(executable), str(fixture), str(output)],
                                    stdout=log, stderr=subprocess.STDOUT, timeout=180)
        print((output / 'run.log').read_text(), end='')
    finally:
        lsregister = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
        cleanup_status = 1
        try:
            with (output / 'cleanup.log').open('w') as log:
                cleanup = subprocess.run([lsregister, '-u', str(app)], stdout=log, stderr=subprocess.STDOUT, timeout=30)
            cleanup_status = cleanup.returncode
        except (OSError, subprocess.TimeoutExpired) as error:
            (output / 'cleanup.log').write_text(str(error))
        if cleanup_status:
            print('소유 진단 앱 등록 해제 실패: ' + str(output / 'cleanup.log'), file=sys.stderr)
        after_hash = hashlib.sha256(fixture.read_bytes()).hexdigest()
        (output / 'fixture-integrity.json').write_text(json.dumps({
            'fixture': str(fixture.relative_to(root)) if fixture.is_relative_to(root) else fixture.name,
            'sha256Before': before_hash, 'sha256After': after_hash,
            'unchanged': before_hash == after_hash, 'cleanupStatus': cleanup_status
        }, indent=2) + '\n')
    # 최초 실행 실패를 보존하고, 실행 성공 후 정리 실패만 별도 실패로 반영한다.
    return result.returncode or cleanup_status or int(before_hash != after_hash)


if __name__ == '__main__':
    raise SystemExit(main())
