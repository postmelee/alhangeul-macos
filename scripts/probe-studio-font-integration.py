#!/usr/bin/env python3
"""제품 Coordinator·정식 Studio·fixture 공급의 실제 WKWebView 연결 검증."""
from pathlib import Path
import argparse, platform, plistlib, shutil, subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--interactive', action='store_true', help='검증 후 테스트 문서 창을 직접 조작하도록 유지')
parser.add_argument('--skip-build', action='store_true', help='이전에 빌드한 격리 앱을 사용')
args = parser.parse_args()

root = Path(__file__).resolve().parent.parent
out = root / 'build.noindex/task567/stage3-2'
out.mkdir(parents=True, exist_ok=True)
bundle = root / 'Sources/HostApp/Resources/rhwp-studio'
fixture_tool = root / 'scripts/ci/studio-font-integration-fixture.mjs'
subprocess.run(['node',str(fixture_tool),'create',str(bundle),str(out)],check=True)
app = out / 'StudioFontIntegrationProbe.app'
exe = app / 'Contents/MacOS/StudioFontIntegrationProbe'
exe.parent.mkdir(parents=True, exist_ok=True)
resources = app / 'Contents/Resources'
resources.mkdir(exist_ok=True)
shutil.copytree(root / 'Sources/HostApp/Resources/rhwp-studio', resources / 'rhwp-studio', dirs_exist_ok=True)
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'com.postmelee.alhangeul.StudioFontIntegrationProbe',
    'CFBundleExecutable': exe.name, 'CFBundlePackageType': 'APPL', 'NSHighResolutionCapable': True}))
sources = [p for directory in ('Sources/HostApp','Sources/Shared','Sources/RhwpCoreBridge')
           for p in sorted((root / directory).rglob('*.swift'))
           if p.name not in ('HostApp.swift','UpdateController.swift')]
bridge = root / 'Frameworks/Rhwp.xcframework/macos-arm64_x86_64'
arch = 'arm64' if platform.machine() == 'arm64' else 'x86_64'
cmd = ['xcrun','swiftc','-parse-as-library','-swift-version','5','-target',arch+'-apple-macosx12.0',
       '-module-cache-path',str(root / 'build.noindex/studio-smoke-module-cache'),
       '-I',str(bridge/'Headers'),'-L',str(bridge),'-lrhwp','-lc++','-liconv','-lz']
for framework in ('AppKit','WebKit','SwiftUI','CoreFoundation','CoreText','CoreGraphics','ImageIO',
                  'CoreServices','Network','ApplicationServices','Security','Metal','QuartzCore','IOSurface','ColorSync'):
    cmd += ['-framework',framework]
cmd += list(map(str,sources)) + [str(root / 'Tests/StudioFontIntegrationProbe/main.swift'),'-o',str(exe)]
if not args.skip_build:
    with (out/'integration-build.log').open('w') as log:
        subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=300)
try:
    command = [str(exe),str(out),str(root)]
    if args.interactive:
        with (out/'integration-interactive.log').open('w') as log:
            child = subprocess.Popen(command+['--interactive'],stdout=log,stderr=subprocess.STDOUT)
        print('격리 테스트 창 실행 PID:',child.pid, flush=True)
        result = subprocess.CompletedProcess(command, child.wait())
    else:
        with (out/'integration-run.log').open('w') as log:
            result = subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        print((out/'integration-run.log').read_text(),end='')
finally:
    if not args.interactive:
        subprocess.run(['/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister',
                        '-u',str(app)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=30,check=True)
if result.returncode == 0:
    subprocess.run(['node',str(fixture_tool),'verify',str(bundle),str(out)],check=True)
raise SystemExit(result.returncode)
