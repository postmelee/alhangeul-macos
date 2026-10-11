#!/usr/bin/env python3
"""격리 fixture로 후보 guard를 확인한다. 외부 명령은 mock으로 차단하며 서명/설치하지 않는다."""
import argparse
import copy
import hashlib
import json
import os
import plistlib
import runpy
import shutil
import sys
from pathlib import Path
from unittest.mock import patch
from extension_font_probe_inventory import bundle_inventory, inventory_digest

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--output', type=Path, required=True)
p.add_argument('--task', type=int, choices=[569,580], default=580)
a = p.parse_args(); out = a.output.resolve()
if out.exists() or not out.is_relative_to(ROOT / f'build.noindex/task{a.task}/stage4'):
    raise SystemExit(f'Task {a.task} Stage 4 아래 새 격리 경로가 필요합니다')
out.mkdir(parents=True)
base = out / 'candidate'; base.mkdir()
identifier = f'{a.task}-GUARD-ONLY'
app = base / 'Alhangeul.app'; fixture = base / 'FontExtensionFixtureProbe.app'
for bundle in [app, fixture]:
    (bundle / 'Contents/MacOS').mkdir(parents=True)
    (bundle / 'Contents/Info.plist').write_bytes(plistlib.dumps({
        'CFBundleExecutable': 'guard', 'AlhangeulFontExtensionProbeIdentifier': identifier}))
    (bundle / 'Contents/MacOS/guard').write_bytes(b'guard-only; never executed')
    (bundle / 'Contents/Resources').mkdir()
    (bundle / 'Contents/Resources/value').write_bytes(b'original')
    (bundle / 'Contents/Resources/link').symlink_to('not-present')

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def bundle_hashes():
    return {str(b.relative_to(base)): {'infoSHA256': digest(b/'Contents/Info.plist'),
            'executableSHA256': digest(b/'Contents/MacOS/guard')} for b in [app, fixture]}
receipt = {'fixtureSourceSHA256':digest(ROOT/'Tests/ExtensionFontProbe/fixture.swift'), 'task': a.task, 'probeIdentifier': identifier,
           'sourceSHA256':{str(path.relative_to(ROOT)):digest(path) for path in sorted((ROOT/'Sources').rglob('*.swift'))},
           'coreLockSHA256': digest(ROOT/'rhwp-core.lock'),
           'assetManifestSHA256': digest(ROOT/'Sources/HostApp/Resources/rhwp-studio/manifest.json'),
           'nativeArtifactSHA256': {'Frameworks/generated_rhwp.h':digest(ROOT/'Frameworks/generated_rhwp.h')},
           'samples': [], 'unsignedBundles':bundle_hashes(),
           'unsignedInventory':{b.name:inventory_digest(bundle_inventory(b)) for b in [app,fixture]}}
results = {}

def rejected(name, value, expected, candidate=base):
    (base/'preparation.json').write_text(json.dumps(value))
    argv = ['extension-font-finder-smoke.py', '--candidate-dir', str(candidate), '--mode', 'sign']
    # 어느 경로도 실제 codesign/등록/설치를 실행하면 안 된다.
    with patch.object(sys, 'argv', argv), patch.dict(os.environ, {}, clear=True), \
         patch('subprocess.run', side_effect=AssertionError('external mutation attempted')) as external:
        try:
            runpy.run_path(str(ROOT/'scripts/extension-font-finder-smoke.py'), run_name='__main__')
            raise AssertionError('guard accepted invalid candidate')
        except SystemExit as error:
            assert expected in str(error), (name, str(error))
        assert external.call_count == 0
    results[name] = True

rejected('noSigningAuthorization', receipt, 'PROBE_SIGN_ID')
rejected('wrongPath', receipt, 'Stage 4 후보', ROOT/f'build.noindex/task{a.task}/stage3')
r = copy.deepcopy(receipt); r['task'] = 580 if a.task==569 else 569
rejected('wrongTask', r, '준비 영수증')
r = copy.deepcopy(receipt); r['sourceSHA256'] = {'Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift':'0'*64}
rejected('changedSource', r, '제품 소스')
r = copy.deepcopy(receipt); r['sourceSHA256'].pop(next(iter(r['sourceSHA256'])))
rejected('addedSourceSet', r, '제품 소스')
r = copy.deepcopy(receipt); r['sourceSHA256']['Sources/removed-probe-source.swift'] = '0'*64
rejected('removedSourceSet', r, '제품 소스')
r = copy.deepcopy(receipt); r['coreLockSHA256'] = '0'*64
rejected('changedCore', r, 'core lock')
r = copy.deepcopy(receipt); r['assetManifestSHA256'] = '0'*64
rejected('changedAssetReceipt', r, 'Studio asset')
r = copy.deepcopy(receipt); r['nativeArtifactSHA256']['Frameworks/generated_rhwp.h'] = '0'*64
rejected('changedNativeArtifact', r, 'native 산출물')
r = copy.deepcopy(receipt); r['samples'] = [{'path':str(ROOT/'samples/basic/KTX.hwp'), 'sha256':'0'*64}]
rejected('wrongSamplePath', r, '입력 문서')
sample = base/'sample.hwpx'; sample.write_bytes(b'changed')
r = copy.deepcopy(receipt); r['samples'] = [{'path':str(sample), 'sha256':'0'*64}]
rejected('changedSample', r, '입력 문서')
value = app/'Contents/Resources/value'; value.write_bytes(b'tampered')
rejected('changedUnsignedResource', receipt, 'unsigned 후보 bytes')
value.write_bytes(b'original')
rejected('restoredUnsignedResource', receipt, 'PROBE_SIGN_ID')
clone = out/'clone'; shutil.copytree(app, clone, symlinks=True)
original = bundle_inventory(app); assert bundle_inventory(clone) == original
results['backupContentLinkModeEquality'] = True
cloneFile = clone/'Contents/Resources/value'; cloneFile.chmod(0o600)
assert bundle_inventory(clone) != original
results['changedModeRejected'] = True
cloneFile.chmod(0o644)
link = clone/'Contents/Resources/link'; link.unlink(); link.symlink_to('different-not-present')
assert bundle_inventory(clone) != original
results['changedLinkRejectedWithoutFollowing'] = True
(out/'result.json').write_text(json.dumps({'scope':'controlled fixtures; no external command or actual OS signing/install',
                                        'proofs':results}, indent=2)+'\n')
shutil.rmtree(base); shutil.rmtree(clone)
print('PASS:', len(results), 'candidate/inventory guards; no external mutation')
