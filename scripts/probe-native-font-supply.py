#!/usr/bin/env python3
"""실제 공급 service·공식 matcher·native backend의 격리 수용. 설치/등록/서명 없음."""
import argparse
import subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--output', required=True, type=Path)
a = p.parse_args()
out = a.output.resolve()
if out.exists():
    raise SystemExit('새 출력 경로를 지정해 주세요')
if not out.is_relative_to(ROOT / 'build.noindex'):
    raise SystemExit('build.noindex 아래 경로가 필요합니다')
out.mkdir(parents=True)
core = sorted((ROOT / 'Sources/RhwpCoreBridge').glob('*.swift'))
shared = sorted((ROOT / 'Sources/Shared/FontLibrary').glob('*.swift'))
shared += [ROOT / f'Sources/Shared/{name}.swift' for name in ['HwpPageImageRenderer','HwpNativePageCompositor']]
shared += [ROOT / 'Sources/Shared/NativeFonts/HwpNativeFontPageRenderer.swift']
host = sorted((ROOT / 'Sources/HostApp/Services').glob('InstalledFont*.swift'))
host += [ROOT / f'Sources/HostApp/Services/{name}.swift' for name in ['MacFontDiscovery','HwpNativeFontSupply']]
command = ['swiftc','-parse-as-library','-target','arm64-apple-macosx12.0','-module-cache-path',str(out/'modules'),'-I',str(ROOT/'Frameworks/modulemap')]
command += list(map(str, core + shared + host)) + [str(ROOT/'Tests/NativeFontSupplyProbe/supply/main.swift')]
command += ['-L',str(ROOT/'Frameworks/universal'),'-lrhwp']
for framework in ['JavaScriptCore','CoreText','CoreGraphics','ImageIO','CryptoKit','Foundation','CoreServices','ApplicationServices','Security','Metal','QuartzCore','IOSurface','OpenGL']:
    command += ['-framework',framework]
command += ['-lc++','-lz','-liconv','-o',str(out/'native-supply')]
with (out/'compile.log').open('w') as log:
    subprocess.run(command, cwd=ROOT, stdout=log, stderr=log, check=True)
with (out/'run.log').open('w') as log:
    subprocess.run([str(out/'native-supply'),str(ROOT),str(out)],cwd=out,stdout=log,stderr=log,check=True,timeout=180)
print(f'OK: {out / "result.json"}')
