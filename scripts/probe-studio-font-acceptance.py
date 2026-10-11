#!/usr/bin/env python3
"""실제 Mac 글꼴·제품 Studio의 서명 sandbox 수용. OS 설치/배포를 수행하지 않는다."""
from pathlib import Path
import argparse, hashlib, json, platform, plistlib, shutil, subprocess, time, uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-dir', type=Path, required=True)
parser.add_argument('--sign-identity', required=True, help='기존에 승인된 로컬 코드 서명 인증서')
parser.add_argument('--interactive', action='store_true', help='재실행 수용 후 실제 목록 창 유지')
parser.add_argument('--interactive-only', action='store_true', help='이미 수용한 앱의 실제 목록 창만 다시 실행')
parser.add_argument('--skip-build', action='store_true', help='동일 경로의 이미 서명된 앱 사용')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
out = args.output_dir.resolve()
if not out.is_relative_to(root / 'build.noindex'):
    parser.error('--output-dir must be under build.noindex')
out.mkdir(parents=True, exist_ok=True)
app = out / 'StudioFontAcceptanceProbe.app'
exe = app / 'Contents/MacOS/StudioFontAcceptanceProbe'
bundle_id = 'com.postmelee.alhangeul.StudioFontAcceptanceProbe.' + hashlib.sha256(str(out).encode()).hexdigest()[:8]
bundle = root / 'Sources/HostApp/Resources/rhwp-studio'
fixture = root / 'scripts/ci/studio-font-integration-fixture.mjs'
container = Path.home() / 'Library/Containers' / bundle_id / 'Data/Library/Application Support/StudioFontAcceptanceProbe'
sources = [p for folder in ('Sources/HostApp', 'Sources/Shared', 'Sources/RhwpCoreBridge')
           for p in sorted((root / folder).rglob('*.swift'))
           if p.name not in ('HostApp.swift', 'UpdateController.swift')]
probe = root / 'Tests/StudioFontAcceptanceProbe/main.swift'
bridge = root / 'Frameworks/Rhwp.xcframework/macos-arm64_x86_64'
inputs = sources + [probe, Path(__file__).resolve(), fixture, root / 'rhwp-core.lock'] + list(sorted(bundle.rglob('*'))) + list(sorted(bridge.rglob('*')))
fingerprints = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs if p.is_file()}
receipt = out / 'build-receipt.json'
if args.skip_build:
    saved = json.loads(receipt.read_text())
    if saved['sources'] != fingerprints or saved['executableSHA256'] != hashlib.sha256(exe.read_bytes()).hexdigest() or saved['identity'] != args.sign_identity:
        parser.error('소스·실행 파일·서명 기준이 바뀌었습니다. --skip-build 없이 새 폴더에 빌드하세요.')
if not args.skip_build:
    exe.parent.mkdir(parents=True, exist_ok=True)
    resources = app / 'Contents/Resources'
    resources.mkdir(exist_ok=True)
    shutil.copytree(bundle, resources / 'rhwp-studio', dirs_exist_ok=True)
    subprocess.run(['node', str(fixture), 'create', str(bundle), str(out), 'NanumSquare'], check=True)
    for ext in ('hwp', 'hwpx'):
        shutil.copyfile(out / ('gowun-document.' + ext), resources / ('nanum-document.' + ext))
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
        'CFBundleIdentifier': bundle_id, 'CFBundleExecutable': exe.name, 'CFBundleName': exe.name,
        'CFBundlePackageType': 'APPL', 'CFBundleVersion': '1', 'LSMinimumSystemVersion': '12.0',
        'NSPrincipalClass': 'NSApplication', 'NSHighResolutionCapable': True}))
    # 실제 앱의 파일 선택·bookmark·WebKit 경계. 사용자 App Group은 테스트와 공유하지 않는다.
    entitlements = out / 'acceptance.entitlements'
    entitlements.write_bytes(plistlib.dumps({
        'com.apple.security.app-sandbox': True, 'com.apple.security.network.client': True,
        'com.apple.security.files.user-selected.read-write': True,
        'com.apple.security.files.bookmarks.app-scope': True}))
    arch = 'arm64' if platform.machine() == 'arm64' else 'x86_64'
    command = ['xcrun', 'swiftc', '-parse-as-library', '-swift-version', '5', '-target', arch + '-apple-macosx12.0',
               '-module-cache-path', str(root / 'build.noindex/studio-smoke-module-cache'),
               '-I', str(bridge / 'Headers'), '-L', str(bridge), '-lrhwp', '-lc++', '-liconv', '-lz',
               '-Xlinker', '-weak_framework', '-Xlinker', 'ScreenCaptureKit']
    for framework in ('AppKit', 'WebKit', 'SwiftUI', 'CoreFoundation', 'CoreText', 'CoreGraphics', 'ImageIO',
                      'CoreServices', 'Network', 'ApplicationServices', 'Security', 'Metal', 'QuartzCore', 'IOSurface', 'ColorSync'):
        command += ['-framework', framework]
    command += list(map(str, sources)) + [str(probe), '-o', str(exe)]
    with (out / 'build.log').open('w') as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=300)
    subprocess.run(['codesign', '--force', '--options', 'runtime', '--timestamp=none', '--sign', args.sign_identity,
                    '--entitlements', str(entitlements), str(app)], check=True)
    receipt.write_text(json.dumps({'sources': fingerprints, 'executableSHA256': hashlib.sha256(exe.read_bytes()).hexdigest(),
                                  'identity': args.sign_identity, 'bundleID': bundle_id}, indent=2) + '\n')
subprocess.run(['codesign', '--verify', '--strict', str(app)], check=True)
with (out / 'signature.log').open('w') as log:
    subprocess.run(['codesign', '-dvv', '--entitlements', ':-', str(app)], stdout=log, stderr=subprocess.STDOUT, check=True)

def run(mode, extra):
    label = mode + '-' + str(uuid.uuid4())
    source = container / 'runs' / label
    proof = source / 'result.json'
    with (out / (mode + '-run.log')).open('w') as log:
        command = [str(exe), '--run=' + label] + extra
        if '--interactive' in extra:
            child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 180
            while not proof.exists() and child.poll() is None:
                if time.monotonic() > deadline:
                    child.kill(); child.wait(); raise RuntimeError('체험 앱 수용 timeout')
                time.sleep(0.2)
            if not proof.exists() or json.loads(proof.read_text()).get('passed') is not True:
                child.wait(timeout=10); raise RuntimeError('체험 앱 수용 실패')
            shutil.copytree(source, out / mode, dirs_exist_ok=True)
            print('실제 Mac 글꼴 창 실행 PID:', child.pid, '검증 결과:', out / mode / 'result.json', flush=True)
            result = subprocess.CompletedProcess(command, child.wait())
        else:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
    if source.exists():
        shutil.copytree(source, out / mode, dirs_exist_ok=True)
    proof = out / mode / 'result.json'
    print((out / (mode + '-run.log')).read_text(), end='', flush=True)
    if result.returncode or not proof.exists() or json.loads(proof.read_text()).get('passed') is not True:
        raise RuntimeError('수용 실패: ' + mode)
    return json.loads(proof.read_text())

try:
    if not args.interactive_only:
        first = run('first', [])
        subprocess.run(['node', str(fixture), 'verify-live', str(bundle), str(out / 'first'), first['measurements']['testFamily']], check=True)
        run('reopen', ['--reopen'])
    if args.interactive or args.interactive_only:
        # 기존 저장 문서를 그대로 열고 실제 설치 목록의 UI를 조작하도록 유지한다.
        run('interactive', ['--reopen', '--interactive'])
finally:
    subprocess.run(['/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister',
                    '-u', str(app)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=30)
