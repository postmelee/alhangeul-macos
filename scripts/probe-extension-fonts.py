#!/usr/bin/env python3
"""공통 확장 공급·렌더·캐시의 unsigned 격리 수용. 설치·등록·인증서 사용 없음."""
import argparse, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--output',type=Path,required=True)
a=p.parse_args(); out=a.output.resolve()
if out.exists() or not out.is_relative_to(ROOT/'build.noindex'):
    raise SystemExit('build.noindex 아래 새 경로가 필요합니다')
out.mkdir(parents=True)
sources=sorted((ROOT/'Sources/RhwpCoreBridge').glob('*.swift'))
sources+=sorted((ROOT/'Sources/Shared/FontLibrary').glob('*.swift'))
sources+=sorted((ROOT/'Sources/Shared/NativeFonts').glob('*.swift'))
sources+=[ROOT/f'Sources/Shared/{name}.swift' for name in ['HwpPageImageRenderer','HwpNativePageCompositor','HwpPreviewPDFRenderer','HwpPreviewPNGRenderer','HwpExternalImageResolver']]
sources+=[ROOT/'Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift',ROOT/'Tests/ExtensionFontProbe/main.swift']
cmd=['swiftc','-parse-as-library','-target','arm64-apple-macosx12.0','-module-cache-path',str(out/'modules'),'-I',str(ROOT/'Frameworks/modulemap')]
cmd+=list(map(str,sources))+['-L',str(ROOT/'Frameworks/universal'),'-lrhwp']
for f in ['JavaScriptCore','CoreText','CoreGraphics','ImageIO','Foundation','CoreServices','ApplicationServices','Security','Metal','QuartzCore','IOSurface','OpenGL']:
    cmd+=['-framework',f]
cmd+=['-lc++','-lz','-liconv','-o',str(out/'extension-probe')]
with (out/'compile.log').open('w') as log: subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=log,check=True)
with (out/'run.log').open('w') as log: subprocess.run([str(out/'extension-probe'),str(ROOT),str(out)],stdout=log,stderr=log,check=True,timeout=180)
print(f'PASS: {out/"result.json"}')
