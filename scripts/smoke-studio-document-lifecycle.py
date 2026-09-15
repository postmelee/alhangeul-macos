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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture', type=pathlib.Path, required=True, help='읽기 전용 HWP/HWPX 입력')
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parent.parent
    fixture = args.fixture.resolve(strict=True)
    build = root / 'build.noindex'
    build.mkdir(exist_ok=True)
    output = pathlib.Path(tempfile.mkdtemp(prefix='studio-lifecycle-', dir=build))
    app = output / 'StudioLifecycleSmoke.app'
    executable = app / 'Contents/MacOS/StudioLifecycleSmoke'
    executable.parent.mkdir(parents=True)
    resources = app / 'Contents/Resources'
    resources.mkdir()
    shutil.copytree(root / 'Sources/HostApp/Resources/rhwp-studio', resources / 'rhwp-studio')
    # 독립 preferences/draft 저장소를 사용한다. 사용자 앱 bundle ID를 재사용하지 않는다.
    info = {'CFBundleIdentifier': 'com.postmelee.studio-lifecycle.' + output.name,
            'CFBundleExecutable': executable.name, 'CFBundleName': 'StudioLifecycleSmoke',
            'CFBundlePackageType': 'APPL'}
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
    command += [str(root / 'Tests/StudioDocumentLifecycleSmoke/main.swift'), '-o', str(executable)]
    print('Evidence:', output, flush=True)
    with (output / 'build.log').open('w') as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=300)
    # 파일/상태를 보존하고 해당 실행 소유 앱의 LaunchServices 등록만 해제한다.
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
    # 최초 실행 실패를 보존하고, 실행 성공 후 정리 실패만 별도 실패로 반영한다.
    return result.returncode or cleanup_status


if __name__ == '__main__':
    raise SystemExit(main())
