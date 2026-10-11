#!/usr/bin/env python3
"""#568 Stage 3: 실제 editor PDF/인쇄 공급 수용. 설치·물리 인쇄·배포 없음."""
from pathlib import Path
import argparse, hashlib, json, platform, plistlib, shutil, subprocess, time, uuid

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--output-dir', type=Path, required=True)
p.add_argument('--font-dir', type=Path, required=True)
p.add_argument('--sign-identity', default='-')
p.add_argument('--sandbox', action='store_true')
p.add_argument('--build-only', action='store_true')
p.add_argument('--skip-build', action='store_true')
p.add_argument('--source', choices=['managed','installed','baseline','all'], default='all')
p.add_argument('--interactive', action='store_true')
p.add_argument('--panel', action='store_true', help='실제 패널을 열어 취소 수용을 기다림. 프린터 전송 금지')
a = p.parse_args()
root = Path(__file__).resolve().parent.parent
out = a.output_dir.resolve()
if not out.is_relative_to(root / 'build.noindex/task568/stage3'):
    p.error('새 build.noindex/task568/stage3 하위 경로가 필요합니다')
out.mkdir(parents=True, exist_ok=True)
app = out / 'StudioOutputAcceptanceProbe.app'
exe = app / 'Contents/MacOS/StudioOutputAcceptanceProbe'
bundle_id = 'com.postmelee.alhangeul.OutputAcceptance.' + hashlib.sha256(str(out).encode()).hexdigest()[:10]
if a.skip_build:
    bundle_id = plistlib.loads((app / 'Contents/Info.plist').read_bytes())['CFBundleIdentifier']
bundle = root / 'Sources/HostApp/Resources/rhwp-studio'
bridge = root / 'Frameworks/Rhwp.xcframework/macos-arm64_x86_64'
sources = [f for folder in ('Sources/HostApp','Sources/Shared','Sources/RhwpCoreBridge')
           for f in sorted((root / folder).rglob('*.swift')) if f.name not in ('HostApp.swift','UpdateController.swift')]
sources += [root / 'Tests/StudioOutputAcceptanceProbe/main.swift',root / 'Tests/HostAppTests/CGPDFFontResourceInspector.swift']
inputs = sources + [root / 'scripts/ci/studio-font-integration-fixture.mjs'] + [f for f in bundle.rglob('*') if f.is_file()]
fingerprints = {str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs}
runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
receipt = out / 'receipt.json'
if a.skip_build:
    saved = json.loads(receipt.read_text())
    # 실행 driver 수정은 컴파일된 Swift/자산 수정과 구분한다. 구 receipt의 driver 행만 제외한다.
    compiled = {k:v for k,v in saved['sources'].items() if k != str(Path(__file__).resolve().relative_to(root))}
    if compiled != fingerprints or saved['signature'] != a.sign_identity or saved['sandbox'] != a.sandbox \
       or saved['bundleID'] != bundle_id or saved['executableSHA256'] != hashlib.sha256(exe.read_bytes()).hexdigest():
        p.error('소스·서명 설정이 달라졌습니다. 새 폴더에 빌드하세요')
elif app.exists():
    p.error('기존 앱은 덮지 않습니다. 새 경로를 사용하세요')
else:
    exe.parent.mkdir(parents=True)
    resources = app / 'Contents/Resources'; resources.mkdir()
    shutil.copytree(bundle,resources / 'rhwp-studio')
    fonts = resources / 'test-fonts'; fonts.mkdir()
    expected = {'GowunBatang-Regular.ttf':'466c593e7147412e748af4856d5ad14709b5a860bdf62b9c2546f2c5874e9849',
                'GowunBatang-Bold.ttf':'dbfcaa646e5831e7478524924f02906f550285a5050699b4e38c9950b3ec4b94'}
    for name,sha in expected.items():
        f = a.font_dir.resolve() / name
        assert hashlib.sha256(f.read_bytes()).hexdigest() == sha
        shutil.copyfile(f,fonts / name)
    shutil.copyfile(a.font_dir.resolve() / 'OFL.txt',fonts / 'OFL.txt')
    fixture = root / 'scripts/ci/studio-font-integration-fixture.mjs'
    for family,prefix in [('Gowun Batang','gowun'),('NanumSquare','nanum')]:
        subprocess.run(['node',str(fixture),'create',str(bundle),str(out),family],check=True)
        for ext in ['hwp','hwpx']:
            shutil.copyfile(out / ('gowun-document.'+ext),resources / (prefix+'-document.'+ext))
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
        'CFBundleIdentifier':bundle_id,'CFBundleExecutable':exe.name,'CFBundleName':exe.name,
        'CFBundlePackageType':'APPL','CFBundleVersion':'1','LSMinimumSystemVersion':'12.0',
        'NSPrincipalClass':'NSApplication','NSHighResolutionCapable':True}))
    arch = 'arm64' if platform.machine() == 'arm64' else 'x86_64'
    cmd = ['xcrun','swiftc','-parse-as-library','-swift-version','5','-target',arch+'-apple-macosx12.0',
           '-module-cache-path',str(root / 'build.noindex/studio-smoke-module-cache'),'-I',str(bridge / 'Headers'),
           '-L',str(bridge),'-lrhwp','-lc++','-liconv','-lz','-Xlinker','-weak_framework','-Xlinker','ScreenCaptureKit']
    for framework in ('AppKit','WebKit','SwiftUI','PDFKit','CoreFoundation','CoreText','CoreGraphics','ImageIO',
                      'CoreServices','Network','ApplicationServices','Security','Metal','QuartzCore','IOSurface','ColorSync'):
        cmd += ['-framework',framework]
    with (out / 'build.log').open('w') as log:
        subprocess.run(cmd + list(map(str,sources)) + ['-o',str(exe)],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=300)
    sign = ['codesign','--force','--timestamp=none','--sign',a.sign_identity]
    if a.sandbox:
        entitlements = out / 'probe.entitlements'
        entitlements.write_bytes(plistlib.dumps({'com.apple.security.app-sandbox':True,'com.apple.security.network.client':True,
            'com.apple.security.files.user-selected.read-write':True,'com.apple.security.files.bookmarks.app-scope':True,
            'com.apple.security.print':True}))
        sign += ['--options','runtime','--entitlements',str(entitlements)]
    subprocess.run(sign + [str(app)],check=True)
    receipt.write_text(json.dumps({'sources':fingerprints,'builtByRunnerSHA256':runner_hash,'signature':a.sign_identity,'sandbox':a.sandbox,'bundleID':bundle_id,
        'executableSHA256':hashlib.sha256(exe.read_bytes()).hexdigest()},indent=2)+'\n')
subprocess.run(['codesign','--verify','--strict',str(app)],check=True)
if a.build_only:
    print('준비된 앱:',app); raise SystemExit(0)
support = Path.home() / 'Library/Application Support'
if a.sandbox:
    support = Path.home() / 'Library/Containers' / bundle_id / 'Data/Library/Application Support'
try:
    modes = ['managed','installed','baseline'] if a.source == 'all' else [a.source]
    for mode in modes:
        label = mode + '-' + str(uuid.uuid4())
        extra = (['--interactive'] if a.interactive else []) + (['--panel'] if a.panel else [])
        with (out / (mode+'-run.log')).open('w') as log:
            command = [str(exe),'--run='+label,'--source='+mode]+extra
            if a.interactive:
                child = subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT)
                proof = support / 'StudioOutputAcceptanceProbe/runs' / label / 'result.json'
                end = time.monotonic() + (240 if a.panel else 180)
                while not proof.exists() and child.poll() is None:
                    if time.monotonic() >= end:
                        child.kill(); child.wait(); raise RuntimeError('체험 앱 수용 timeout')
                    time.sleep(0.2)
                result = subprocess.CompletedProcess(command,child.poll() or 0)
                print('체험 창 PID:',child.pid,flush=True)
            else:
                result = subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=240 if a.panel else 180)
        source = support / 'StudioOutputAcceptanceProbe/runs' / label
        if source.exists(): shutil.copytree(source,out / mode,dirs_exist_ok=True)
        with (out / 'runs.jsonl').open('a') as journal:
            journal.write(json.dumps({'label':label,'source':mode,'driverSHA256':runner_hash,'bundleID':bundle_id,
                'signature':a.sign_identity,'panel':a.panel,'interactive':a.interactive})+'\n')
        print((out / (mode+'-run.log')).read_text(),end='',flush=True)
        proof = out / mode / 'result.json'
        if result.returncode or not proof.exists() or json.loads(proof.read_text())['passed'] is not True:
            raise RuntimeError('실제 출력 수용 실패: '+mode)
finally:
    ls = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
    unregister = subprocess.run([ls,'-u',str(app)],capture_output=True,text=True,timeout=30)
    dump = subprocess.run([ls,'-dump'],capture_output=True,text=True,check=True,timeout=30)
    registered = str(app) in dump.stdout
    (out / 'cleanup.json').write_text(json.dumps({'unregisterExitCode':unregister.returncode,'registeredAfter':registered})+'\n')
    if registered: raise RuntimeError('격리 앱 등록이 남아 있습니다')
