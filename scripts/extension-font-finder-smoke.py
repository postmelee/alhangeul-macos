#!/usr/bin/env python3
"""명시 승인 후에만 실행한다. 준비/서명/표준 설치 smoke/복원 모드를 분리한다."""
import argparse, hashlib, json, os, plistlib, shutil, subprocess, signal, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
INSTALL=Path('/Applications/Alhangeul.app')
LS=Path('/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister')
p=argparse.ArgumentParser(); p.add_argument('--candidate-dir',type=Path,required=True)
p.add_argument('--mode',choices=['plan','sign','install','restore'],default='plan'); a=p.parse_args()
base=a.candidate_dir.resolve()
legacy=base.is_relative_to(ROOT/'build.noindex/task568/stage5')
performance=base.is_relative_to(ROOT/'build.noindex/task569/stage2')
if not (legacy or performance): raise SystemExit('Task 568 Stage 5 또는 Task 569 Stage 2 후보만 사용합니다')
receipt=json.loads((base/'preparation.json').read_text()); identifier=receipt['probeIdentifier']
if performance and receipt.get('task')!=569: raise SystemExit('Task 569 준비 영수증이 필요합니다')
app=base/'Alhangeul.app'; fixture=base/'FontExtensionFixtureProbe.app'; stateFile=base/'install-state.json'
def run(args,**kw): return subprocess.run(list(map(str,args)),check=True,**kw)
def info(bundle): return plistlib.loads((bundle/'Contents/Info.plist').read_bytes())
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def seal(bundle): run(['codesign','--verify','--deep','--strict',bundle])
def marker(bundle): return info(bundle).get('AlhangeulFontExtensionProbeIdentifier') if bundle.exists() else None
def bundle_hashes():
    return {str(bundle.relative_to(base)):{'infoSHA256':digest(bundle/'Contents/Info.plist'),
        'executableSHA256':digest(bundle/'Contents/MacOS'/info(bundle)['CFBundleExecutable'])}
        for bundle in [app,fixture]+sorted((app/'Contents/PlugIns').glob('*.appex'))}
def unregister(bundle):
    for child in (bundle/'Contents/PlugIns').glob('*.appex') if bundle.exists() else []:
        subprocess.run(['pluginkit','-r',str(child)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    subprocess.run([str(LS),'-u',str(bundle)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    updater=bundle/'Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app'
    subprocess.run([str(LS),'-u',str(updater)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
def register(bundle):
    run([LS,'-f','-R','-trusted',bundle]); run(['pluginkit','-a',bundle])
    for name in ['QLExtension','ThumbnailExtension']: run(['pluginkit','-e','use','-i','com.postmelee.alhangeul.'+name])
def restore():
    if not stateFile.exists(): raise SystemExit('이 실행의 백업 상태가 없습니다')
    state=json.loads(stateFile.read_text()); backup=base/'backup/Alhangeul.app'
    if state['probeIdentifier']!=identifier: raise SystemExit('다른 실행의 백업입니다')
    seal(backup)
    if digest(backup/'Contents/Info.plist')!=state['originalInfoSHA256']: raise SystemExit('백업 identity가 바뀌었습니다')
    if marker(INSTALL)==identifier:
        unregister(INSTALL); shutil.rmtree(INSTALL); run(['ditto',backup,INSTALL])
    elif not INSTALL.exists():
        run(['ditto',backup,INSTALL])
    elif digest(INSTALL/'Contents/Info.plist')!=state['originalInfoSHA256']:
        raise SystemExit('설치본이 다른 작업에서 바뀌어 자동 복원을 중단합니다')
    seal(INSTALL); register(INSTALL)
    if marker(fixture)==identifier:
        run([fixture/'Contents/MacOS/FontExtensionFixtureProbe','--cleanup'])
    unregister(app); unregister(fixture); unregister(backup)
    state['restored']=True; stateFile.write_text(json.dumps(state,indent=2)+'\n')
    print('원래 설치본 복원 완료. 전역 캐시 reset을 수행하지 않았습니다.')
if a.mode=='plan':
    print(json.dumps({'candidate':str(app),'fixture':str(fixture),'probeIdentifier':identifier,
        'installTarget':str(INSTALL),'backup':str(base/'backup/Alhangeul.app'),
        'task':receipt.get('task',568),'installedInfoSHA256':digest(INSTALL/'Contents/Info.plist') if INSTALL.exists() else None,
        'installedVersion':info(INSTALL).get('CFBundleShortVersionString') if INSTALL.exists() else None,
        'globalReset':False,'otherRegistrationsChanged':False},indent=2)); raise SystemExit()
if a.mode=='restore': restore(); raise SystemExit()
if performance:
    if any(digest(ROOT/path)!=expected for path,expected in receipt['sourceSHA256'].items()):
        raise SystemExit('후보 준비 이후 제품 소스가 변경됐습니다')
    if digest(ROOT/'rhwp-core.lock')!=receipt['coreLockSHA256']: raise SystemExit('core lock이 변경됐습니다')
    for sample in receipt['samples']:
        path=Path(sample['path'])
        if not path.is_relative_to(ROOT/'build.noindex/task569/stage2') or digest(path)!=sample['sha256']:
            raise SystemExit('Task 569 입력 문서 경로/hash 불일치')
for bundle in [app,fixture]+sorted((app/'Contents/PlugIns').glob('*.appex')):
    if marker(bundle)!=identifier: raise SystemExit('같은 고유 테스트 보관함 설정이 필요합니다')
if a.mode=='sign':
    if performance and bundle_hashes()!=receipt['unsignedBundles']: raise SystemExit('준비한 unsigned 후보 bytes가 변경됐습니다')
    identity=os.environ.get('PROBE_SIGN_ID')
    if not identity: raise SystemExit('승인한 PROBE_SIGN_ID가 필요합니다')
    def sign(bundle,entitlements=None):
        args=['codesign','--force','--sign',identity,'--options','runtime','--timestamp=none']
        args+=['--entitlements',entitlements] if entitlements else ['--preserve-metadata=entitlements']
        run(args+[bundle])
    sparkle=app/'Contents/Frameworks/Sparkle.framework'
    for name in ['XPCServices/Downloader.xpc','XPCServices/Installer.xpc','Updater.app','Autoupdate']:
        child=sparkle/'Versions/B'/name
        if child.exists(): sign(child)
    if sparkle.exists(): sign(sparkle)
    importer=app/'Contents/Library/Spotlight/Alhangeul.mdimporter'
    if importer.exists(): sign(importer)
    for target,name in [('QLExtension','AlhangeulPreview.appex'),('ThumbnailExtension','AlhangeulThumbnail.appex'),('HostApp',None)]:
        source=ROOT/f'Sources/{target}/{target}.entitlements'
        expanded=source.read_text().replace('$(PRODUCT_BUNDLE_IDENTIFIER)','com.postmelee.alhangeul')
        entitlementFile=base/(target+'.entitlements'); entitlementFile.write_text(expanded)
        sign(app/'Contents/PlugIns'/name if name else app,entitlementFile)
    sign(fixture,base/'fixture.entitlements'); seal(app); seal(fixture)
    if performance: (base/'signed-bundles.json').write_text(json.dumps(bundle_hashes(),indent=2)+'\n')
    print('로컬 서명 완료. 설치/공증/공개 배포 없음.'); raise SystemExit()
if performance and bundle_hashes()!=json.loads((base/'signed-bundles.json').read_text()): raise SystemExit('서명한 후보 bytes가 변경됐습니다')
seal(app); seal(fixture)
if stateFile.exists(): raise SystemExit('기존 실행 상태가 있습니다. 우선 복원 상태를 확인하세요')
if not INSTALL.exists(): raise SystemExit('승인 대상 기존 설치본이 없습니다')
if performance:
    plan=json.loads((base/'operation-plan.json').read_text())
    if digest(INSTALL/'Contents/Info.plist')!=plan['installedInfoSHA256']:
        raise SystemExit('승인 준비 시점의 설치본이 변경됐습니다. 새 복원 계획이 필요합니다')
if (Path.home()/'Applications/Alhangeul.app').exists(): raise SystemExit('다른 설치본을 삭제하지 않습니다')
# 사용자 HostApp/기존 확장이 실행 중이면 교체하지 않는다. 종료는 직접 확인한 다음 수행한다.
for executable in ['Alhangeul','AlhangeulPreview']:
    if subprocess.run(['pgrep','-x',executable],stdout=subprocess.DEVNULL).returncode==0:
        raise SystemExit('설치본 관련 창을 닫고 다시 진행해야 합니다: '+executable)
backup=base/'backup/Alhangeul.app'; backup.parent.mkdir()
run(['ditto',INSTALL,backup]); seal(backup)
state={'probeIdentifier':identifier,'originalInfoSHA256':digest(INSTALL/'Contents/Info.plist'),'restored':False}
stateFile.write_text(json.dumps(state,indent=2)+'\n')
try:
    # 창 없는 Thumbnail worker는 앱을 닫아도 남는다. 설치 대상의 정확한 실행 경로만 종료한다.
    executable=str(INSTALL/'Contents/PlugIns/AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail')
    processes=subprocess.check_output(['ps','-axo','pid=,comm='],text=True)
    for line in processes.splitlines():
        fields=line.strip().split(None,1)
        if len(fields)!=2 or fields[1]!=executable: continue
        pid=int(fields[0]); os.kill(pid,signal.SIGTERM)
        for _ in range(50):
            try: os.kill(pid,0)
            except ProcessLookupError: break
            time.sleep(0.1)
        else: raise RuntimeError('대상 Thumbnail worker가 종료되지 않아 교체를 중단합니다')
    run([fixture/'Contents/MacOS/FontExtensionFixtureProbe','--setup'])
    samples=[Path(s['path']) for s in receipt['samples']] if performance else [ROOT/'build.noindex/task568/stage3/fixtures/gowun-document.hwp',ROOT/'build.noindex/task568/stage3/fixtures/gowun-document.hwpx',
        ROOT/'build.noindex/task568/stage5/probe-inputs/multiple-two.hwpx',ROOT/'build.noindex/task568/stage4/installed-wide.hwpx']
    args=['bash',ROOT/'scripts/smoke-clean-quicklook-install.sh','--app',app,'--install-app',INSTALL,
        '--replace-applications-install','--preserve-signature','--scoped-registrations','--skip-global-reset','--output-dir',base/'finder-results']
    for sample in samples: args+=['--sample',sample]
    run(args)
except BaseException:
    restore(); raise
print('표준 smoke 완료. 수동 Quick Look 확인 후 같은 후보의 --mode restore를 반드시 실행합니다.')
