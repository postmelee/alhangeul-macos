#!/usr/bin/env python3
"""승인된 Task 568/569/580의 signed smoke 후보만 준비한다. 서명·설치·등록은 하지 않는다."""
import argparse, hashlib, json, plistlib, platform, shutil, subprocess, uuid
from pathlib import Path
from extension_font_probe_inventory import bundle_inventory, inventory_digest
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--output',type=Path,required=True)
p.add_argument('--built-app',type=Path,required=True)
p.add_argument('--task',type=int,choices=[568,569,580],default=568)
p.add_argument('--probe-revision',type=int,choices=range(1,100),default=1)
p.add_argument('--samples-dir',type=Path)
a=p.parse_args(); out=a.output.resolve(); app=a.built_app.resolve()
allowed=ROOT/f'build.noindex/task{a.task}/stage{5 if a.task==568 else 4}'
if out.exists() or not out.is_relative_to(allowed):
    raise SystemExit('해당 타스크 단계 아래 새 경로가 필요합니다')
if not app.is_relative_to(ROOT/'build.noindex') or not app.is_dir(): raise SystemExit('격리 빌드 앱이 필요합니다')
samples=[]
if a.task in (569,580):
    if not a.samples_dir or not a.samples_dir.resolve().is_relative_to(allowed):
        raise SystemExit(f'Task {a.task}의 hash 검증 입력 폴더가 필요합니다')
    audit=json.loads((ROOT/'Tests/ExtensionFontPerformanceProbe/fixtures.json').read_text())
    for entry,name in zip(audit['fixtures'],['single.hwp','single.hwpx','two.hwpx']):
        path=a.samples_dir.resolve()/name
        if hashlib.sha256(path.read_bytes()).hexdigest()!=entry['sha256']:
            raise SystemExit('입력 문서 hash 불일치')
        samples.append({'path':str(path),'sha256':entry['sha256']})
for bundle in [app]+sorted((app/'Contents/PlugIns').glob('*.appex')):
    metadata=plistlib.loads((bundle/'Contents/Info.plist').read_bytes())
    executable=bundle/'Contents/MacOS'/metadata['CFBundleExecutable']
    if b'AlhangeulFontExtensionProbeIdentifier' not in executable.read_bytes():
        raise SystemExit('probe flag로 빌드한 앱/확장만 사용합니다: '+bundle.name)
    if a.task in (569,580) and bundle.suffix=='.appex' and b'FontPerformance request=' not in executable.read_bytes():
        raise SystemExit(f'Task {a.task} 요청 시간 진단이 없는 확장입니다: '+bundle.name)
out.mkdir(parents=True); identifier=str(uuid.uuid4()).upper()
subprocess.run(['ditto',str(app),str(out/'Alhangeul.app')],check=True)
candidate=out/'Alhangeul.app'
for bundle in [candidate]+sorted((candidate/'Contents/PlugIns').glob('*.appex')):
    info=bundle/'Contents/Info.plist'; data=plistlib.loads(info.read_bytes())
    data['AlhangeulFontExtensionProbeIdentifier']=identifier
    data['CFBundleVersion']=f'{a.task}.{5 if a.task==568 else 4}.{a.probe_revision}'
    info.write_bytes(plistlib.dumps(data))
fixture=out/'FontExtensionFixtureProbe.app'
(fixture/'Contents/MacOS').mkdir(parents=True)
fonts=fixture/'Contents/Resources/Fonts'; fonts.mkdir(parents=True)
source=ROOT/'build.noindex/task567/fonts/gowun-batang'
if a.task in (569,580):
    for entry in audit['originalFonts']['verifiedFiles']:
        if hashlib.sha256((ROOT/entry['path']).read_bytes()).hexdigest()!=entry['sha256']:
            raise SystemExit('OFL 원본 hash 불일치')
for name in ['GowunBatang-Regular.ttf','GowunBatang-Bold.ttf','OFL.txt']: shutil.copy2(source/name,fonts/name)
group='XH6JHKYXV8.com.postmelee.alhangeul.font-library'
(fixture/'Contents/Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='com.postmelee.alhangeul.FontExtensionFixtureProbe.'+identifier,
    CFBundleExecutable='FontExtensionFixtureProbe',CFBundlePackageType='APPL',CFBundleVersion='1',LSMinimumSystemVersion='12.0',LSUIElement=True,
    AlhangeulFontLibraryGroupIdentifier=group,AlhangeulFontExtensionProbeIdentifier=identifier)))
entitlements={'com.apple.security.app-sandbox':True,'com.apple.security.application-groups':[group]}
(out/'fixture.entitlements').write_bytes(plistlib.dumps(entitlements))
sources=sorted((ROOT/'Sources/Shared/FontLibrary').glob('*.swift'))+[ROOT/'Tests/ExtensionFontProbe/fixture.swift']
cmd=['swiftc','-parse-as-library','-D','ALHANGEUL_FONT_EXTENSION_PROBE','-target',platform.machine()+'-apple-macosx12.0',
    '-module-cache-path',str(out/'modules')]+list(map(str,sources))+['-o',str(fixture/'Contents/MacOS/FontExtensionFixtureProbe')]
with (out/'fixture-compile.log').open('w') as log: subprocess.run(cmd,stdout=log,stderr=log,check=True)
receipt={'version':2,'task':a.task,'probeIdentifier':identifier,'groupIdentifier':group,'candidate':str(candidate),'fixture':str(fixture),
    'scope':'unsigned only; no installation, signing or fixture setup',
    'requiredBuildFlag':'ALHANGEUL_FONT_EXTENSION_PROBE','samples':samples,
    'fixtureSourceSHA256':hashlib.sha256((ROOT/'Tests/ExtensionFontProbe/fixture.swift').read_bytes()).hexdigest(),
    'sourceCommit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    'sourceSHA256':{str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted((ROOT/'Sources').rglob('*.swift'))},
    'assetManifestSHA256':hashlib.sha256((ROOT/'Sources/HostApp/Resources/rhwp-studio/manifest.json').read_bytes()).hexdigest(),
    'nativeArtifactSHA256':{str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in [ROOT/'Frameworks/universal/librhwp.a',ROOT/'Frameworks/generated_rhwp.h']},
    'coreLockSHA256':hashlib.sha256((ROOT/'rhwp-core.lock').read_bytes()).hexdigest(),
    'fonts':{name:hashlib.sha256((fonts/name).read_bytes()).hexdigest() for name in ['GowunBatang-Regular.ttf','GowunBatang-Bold.ttf']}}
receipt['unsignedInventory']={bundle.name:inventory_digest(bundle_inventory(bundle)) for bundle in [candidate,fixture]}
receipt['unsignedBundles']={str(bundle.relative_to(out)):{'infoSHA256':hashlib.sha256((bundle/'Contents/Info.plist').read_bytes()).hexdigest(),
    'executableSHA256':hashlib.sha256((bundle/'Contents/MacOS'/plistlib.loads((bundle/'Contents/Info.plist').read_bytes())['CFBundleExecutable']).read_bytes()).hexdigest()}
    for bundle in [candidate,fixture]+sorted((candidate/'Contents/PlugIns').glob('*.appex'))}
(out/'preparation.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(out/'preparation.json')
