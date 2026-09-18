#!/usr/bin/env python3
"""빌드한 Debug HostApp 복사본의 서명·App Group·재실행을 격리 검증한다. 배포/공증하지 않는다."""
import argparse
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import time
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=pathlib.Path)
    parser.add_argument('identity', help='로컬 Developer ID Application 인증서')
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parent.parent
    build = (root / 'build.noindex').resolve()
    source = args.app.resolve(strict=True)
    if build not in source.parents:
        parser.error('build.noindex의 Debug 산출물만 허용합니다')
    binaries = [source / 'Contents/MacOS/Alhangeul', source / 'Contents/MacOS/Alhangeul.debug.dylib']
    if not any(b'--font-library-host-probe' in binary.read_bytes() for binary in binaries if binary.is_file()):
        parser.error('진단 진입점이 포함된 Debug HostApp이 필요합니다')
    output = pathlib.Path(tempfile.mkdtemp(prefix='font-host-probe-', dir=build))
    app = output / 'FontLibraryHostProbe.app'
    shutil.copytree(source, app, symlinks=True)
    info_path = app / 'Contents/Info.plist'
    info = plistlib.loads(info_path.read_bytes())
    info['CFBundleIdentifier'] = 'com.postmelee.alhangeul.font-host-probe'
    info['LSUIElement'] = True
    info_path.write_bytes(plistlib.dumps(info))
    shutil.copyfile(root / 'Tests/FontLibraryTests/Fixtures/regular.ttf', app / 'Contents/Resources/font-probe.ttf')

    def run(command):
        subprocess.run(command, check=True, timeout=180)

    def sign(path, entitlements=None):
        command = ['codesign', '--force', '--options', 'runtime', '--timestamp=none', '--sign', args.identity]
        if entitlements:
            command += ['--entitlements', str(entitlements)]
        run(command + [str(path)])

    # Xcode Debug 실행 파일은 별도 dylib을 적재한다. hardened runtime의 동일 팀 검증을 유지한다.
    for library in sorted((app / 'Contents').rglob('*.dylib')):
        if not library.is_symlink():
            sign(library)

    sparkle = app / 'Contents/Frameworks/Sparkle.framework'
    version = (sparkle / 'Versions/Current').resolve()
    for part in ('XPCServices/Downloader.xpc', 'XPCServices/Installer.xpc', 'Updater.app', 'Autoupdate'):
        sign(version / part)
    sign(sparkle)
    for name, target in [('AlhangeulPreview.appex', 'QLExtension'), ('AlhangeulThumbnail.appex', 'ThumbnailExtension')]:
        extension = app / 'Contents/PlugIns' / name
        entitlements = output / (target + '.entitlements')
        entitlements.write_bytes((root / 'Sources' / target / (target + '.entitlements')).read_bytes())
        sign(extension, entitlements)
    sign(app / 'Contents/Library/Spotlight/Alhangeul.mdimporter')
    entitlements = output / 'host.entitlements'
    entitlements.write_text((root / 'Sources/HostApp/HostApp.entitlements').read_text().replace(
        '$(PRODUCT_BUNDLE_IDENTIFIER)', info['CFBundleIdentifier']))
    sign(app, entitlements)
    run(['codesign', '--verify', '--deep', '--strict', str(app)])
    session = str(uuid.uuid4())
    group = info['AlhangeulFontLibraryGroupIdentifier']
    isolated = pathlib.Path.home() / 'Library/Group Containers' / group / ('.font-library-host-probe-' + session.upper())
    lsregister = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
    try:
        for phase in ('create', 'reopen'):
            with (output / (phase + '.log')).open('w') as log:
                subprocess.run([str(app / 'Contents/MacOS/Alhangeul'), '--font-library-host-probe', session, phase],
                               stdout=log, stderr=subprocess.STDOUT, check=True, timeout=45)
            text = (output / (phase + '.log')).read_text()
            print(text, end='')
            if 'PASS: HostApp signed font service ' + phase not in text:
                raise RuntimeError('HostApp 진단 성공 표식 없음')
    finally:
        # 해당 진단 복사본의 경로만 해제한다. 다른 앱/확장 등록은 변경하지 않는다.
        cleanup_errors = []
        for extension in (app / 'Contents/PlugIns').glob('*.appex'):
            result = subprocess.run(['pluginkit', '-r', str(extension)], capture_output=True, text=True, timeout=30)
            if result.returncode and 'no plugin at ' + str(extension) not in result.stderr + result.stdout:
                cleanup_errors.append(result.stderr)
        subprocess.run([lsregister, '-u', str(app)], capture_output=True, timeout=30)
        # 검증한 복사본은 재생성 가능하다. 로그를 남기고 소유 앱만 제거한다.
        shutil.rmtree(app)
        if isolated.exists():
            shutil.rmtree(isolated)
        deadline = time.monotonic() + 60
        while True:
            registered = subprocess.run([lsregister, '-dump'], capture_output=True, text=True, check=True, timeout=30).stdout
            if str(app) not in registered:
                break
            if time.monotonic() >= deadline:
                cleanup_errors.append('LaunchServices에 진단 앱 경로가 남음')
                break
            subprocess.run([lsregister, '-u', str(app)], capture_output=True, timeout=30)
            time.sleep(2)
        if cleanup_errors:
            raise RuntimeError('진단 소유 경로 정리 실패: ' + '; '.join(cleanup_errors))
    print('Evidence:', output)


if __name__ == '__main__':
    main()
