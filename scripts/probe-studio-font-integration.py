#!/usr/bin/env python3
"""제품 Coordinator·정식 Studio·fixture 공급의 실제 WKWebView 연결 검증."""
from pathlib import Path
import argparse, hashlib, json, platform, plistlib, shutil, subprocess, uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--interactive', action='store_true', help='검증 후 테스트 문서 창을 직접 조작하도록 유지')
parser.add_argument('--skip-build', action='store_true', help='이전에 빌드한 격리 앱을 사용')
parser.add_argument('--output-dir', type=Path, help='검증 산출물 폴더 (.app은 build.noindex 아래)')
parser.add_argument('--changes', action='store_true', help='격리된 native 설치/관리 변경과 새 프로세스 복원 검증')
parser.add_argument('--settings-navigation', action='store_true', help='실제 SwiftUI Settings Scene으로 연결·가져오기 진입 검증')
args = parser.parse_args()
if args.changes and args.settings_navigation:
    parser.error('--changes and --settings-navigation are separate probes')

root = Path(__file__).resolve().parent.parent
out = (args.output_dir or root / ('build.noindex/task567/stage4-2/settings-navigation' if args.settings_navigation else
       'build.noindex/task567/stage4' if args.changes else 'build.noindex/task567/stage3-3')).resolve()
if not out.is_relative_to(root / 'build.noindex'):
    parser.error('--output-dir must be under build.noindex')
out.mkdir(parents=True, exist_ok=True)
bundle = root / 'Sources/HostApp/Resources/rhwp-studio'
fixture_tool = root / 'scripts/ci/studio-font-integration-fixture.mjs'
subprocess.run(['node',str(fixture_tool),'create',str(bundle),str(out)],check=True)
app_name = 'StudioFontSettingsProbe' if args.settings_navigation else 'StudioFontIntegrationProbe'
app = out / (app_name + '.app')
exe = app / 'Contents/MacOS' / app_name
exe.parent.mkdir(parents=True, exist_ok=True)
resources = app / 'Contents/Resources'
resources.mkdir(exist_ok=True)
shutil.copytree(root / 'Sources/HostApp/Resources/rhwp-studio', resources / 'rhwp-studio', dirs_exist_ok=True)
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': ('com.postmelee.alhangeul.StudioFontSettingsProbe.' + hashlib.sha256(str(out).encode()).hexdigest()[:8]) if args.settings_navigation else
        'com.postmelee.alhangeul.StudioFontChangeProbe' if args.changes else 'com.postmelee.alhangeul.StudioFontIntegrationProbe',
    'CFBundleExecutable': exe.name, 'CFBundleName': app_name, 'CFBundlePackageType': 'APPL',
    'NSPrincipalClass': 'NSApplication', 'NSHighResolutionCapable': True,
    'ProbeOutputRoot': str(out), 'ProbeRepositoryRoot': str(root)}))
sources = [p for directory in ('Sources/HostApp','Sources/Shared','Sources/RhwpCoreBridge')
           for p in sorted((root / directory).rglob('*.swift'))
           if p.name not in ('HostApp.swift','UpdateController.swift')]
bridge = root / 'Frameworks/Rhwp.xcframework/macos-arm64_x86_64'
arch = 'arm64' if platform.machine() == 'arm64' else 'x86_64'
cmd = ['xcrun','swiftc','-parse-as-library','-swift-version','5','-target',arch+'-apple-macosx12.0',
       '-module-cache-path',str(root / 'build.noindex/studio-smoke-module-cache'),
       '-I',str(bridge/'Headers'),'-L',str(bridge),'-lrhwp','-lc++','-liconv','-lz']
cmd += ['-Xlinker','-weak_framework','-Xlinker','ScreenCaptureKit']
for framework in ('AppKit','WebKit','SwiftUI','CoreFoundation','CoreText','CoreGraphics','ImageIO',
                  'CoreServices','Network','ApplicationServices','Security','Metal','QuartzCore','IOSurface','ColorSync'):
    cmd += ['-framework',framework]
probe = 'Tests/StudioFontSettingsProbe' if args.settings_navigation else 'Tests/StudioFontIntegrationProbe'
cmd += list(map(str,sources)) + [str(p) for p in sorted((root / probe).glob('*.swift'))] + ['-o',str(exe)]
if args.settings_navigation:
    cmd.insert(-2, str(root / 'Tests/StudioFontIntegrationProbe/FontChangeFixture.swift'))
if not args.skip_build:
    with (out/'integration-build.log').open('w') as log:
        subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=300)
try:
    command = [str(exe),str(out),str(root)]
    if args.changes:
        state_dir = out / ('change-state-' + str(uuid.uuid4()))
        command += ['--changes', '--state-dir', str(state_dir)]
        for suffix, mode in [('changes', []), ('reopen', ['--reopen']), ('installed-reopen', ['--installed-reopen'])]:
            with (out/(suffix+'-run.log')).open('w') as log:
                result = subprocess.run(command+mode,stdout=log,stderr=subprocess.STDOUT,timeout=300)
            print((out/(suffix+'-run.log')).read_text(),end='',flush=True)
            if result.returncode: raise SystemExit(result.returncode)
        subprocess.run(['node',str(fixture_tool),'verify-changes',str(bundle),str(out)],check=True)
    if args.settings_navigation:
        # 경로는 Info.plist에 기록하고 인자를 최소화한다. 동일한 SwiftUI App을
        # 직접 실행하여 LaunchServices의 시험 번들 캐시/시작 차이와 분리한다.
        log = out / 'settings-navigation-run.log'
        log.write_text('')
        proof = out / 'settings-navigation-result.json'
        proof.unlink(missing_ok=True)
        launch = [str(exe)] + (['--interactive'] if args.interactive else [])
        with log.open('w') as stream:
            result = subprocess.run(launch, stdout=stream, stderr=subprocess.STDOUT, timeout=None if args.interactive else 180)
        print(log.read_text() if log.exists() else '', end='', flush=True)
        passed = proof.exists() and json.loads(proof.read_text()).get('passed') is True
        result = subprocess.CompletedProcess(launch, 0 if result.returncode == 0 and passed else 1)
    elif args.interactive:
        with (out/'integration-interactive.log').open('w') as log:
            child = subprocess.Popen(command+(['--installed-reopen'] if args.changes else [])+['--interactive'],stdout=log,stderr=subprocess.STDOUT)
        print('격리 테스트 창 실행 PID:',child.pid, flush=True)
        result = subprocess.CompletedProcess(command, child.wait())
    elif not args.changes:
        with (out/'integration-run.log').open('w') as log:
            result = subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        print((out/'integration-run.log').read_text(),end='')
finally:
    subprocess.run(['/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister',
                    '-u',str(app)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=30,check=True)
if result.returncode == 0 and not args.changes and not args.settings_navigation:
    subprocess.run(['node',str(fixture_tool),'verify',str(bundle),str(out)],check=True)
raise SystemExit(result.returncode)
