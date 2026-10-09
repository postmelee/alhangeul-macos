#!/usr/bin/env python3
"""Stage 5 signed smoke 후보 준비만 수행한다. 인증서 사용·설치·실행·등록은 하지 않는다."""
import argparse, hashlib, json, plistlib, platform, shutil, subprocess, uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--output',type=Path,required=True)
p.add_argument('--built-app',type=Path,required=True)
a=p.parse_args(); out=a.output.resolve(); app=a.built_app.resolve()
if out.exists() or not out.is_relative_to(ROOT/'build.noindex'):
    raise SystemExit('build.noindex 아래 새 경로가 필요합니다')
if not app.is_relative_to(ROOT/'build.noindex') or not app.is_dir(): raise SystemExit('격리 빌드 앱이 필요합니다')
for bundle in [app]+sorted((app/'Contents/PlugIns').glob('*.appex')):
    metadata=plistlib.loads((bundle/'Contents/Info.plist').read_bytes())
    executable=bundle/'Contents/MacOS'/metadata['CFBundleExecutable']
    if b'AlhangeulFontExtensionProbeIdentifier' not in executable.read_bytes():
        raise SystemExit('probe flag로 빌드한 앱/확장만 사용합니다: '+bundle.name)
out.mkdir(parents=True); identifier=str(uuid.uuid4()).upper()
subprocess.run(['ditto',str(app),str(out/'Alhangeul.app')],check=True)
candidate=out/'Alhangeul.app'
for bundle in [candidate]+sorted((candidate/'Contents/PlugIns').glob('*.appex')):
    info=bundle/'Contents/Info.plist'; data=plistlib.loads(info.read_bytes())
    data['AlhangeulFontExtensionProbeIdentifier']=identifier
    data['CFBundleVersion']='568.5.1'
    info.write_bytes(plistlib.dumps(data))
fixture=out/'FontExtensionFixtureProbe.app'
(fixture/'Contents/MacOS').mkdir(parents=True)
fonts=fixture/'Contents/Resources/Fonts'; fonts.mkdir(parents=True)
source=ROOT/'build.noindex/task567/fonts/gowun-batang'
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
receipt={'version':1,'probeIdentifier':identifier,'groupIdentifier':group,'candidate':str(candidate),'fixture':str(fixture),
    'scope':'unsigned only; no installation, signing or fixture setup',
    'requiredBuildFlag':'ALHANGEUL_FONT_EXTENSION_PROBE','fonts':{name:hashlib.sha256((fonts/name).read_bytes()).hexdigest() for name in ['GowunBatang-Regular.ttf','GowunBatang-Bold.ttf']}}
(out/'preparation.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(out/'preparation.json')
