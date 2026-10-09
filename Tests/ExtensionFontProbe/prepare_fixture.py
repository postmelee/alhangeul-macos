"""기존 합성 HWPX의 본문만 별도 페이지로 반복한다. 원본은 수정하지 않는다."""
import argparse, re, zipfile
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('source',type=Path); p.add_argument('output',type=Path); a=p.parse_args()
if a.output.exists() or a.source.resolve()==a.output.resolve(): raise SystemExit('새 출력 경로가 필요합니다')
with zipfile.ZipFile(a.source) as source,zipfile.ZipFile(a.output,'w') as target:
    for entry in source.infolist():
        data=source.read(entry.filename)
        if entry.filename=='Contents/section0.xml':
            paragraph=re.search(rb'<hp:p\b.*?</hp:p>',data,re.S)
            if not paragraph: raise SystemExit('합성 문단을 확인할 수 없습니다')
            repeated=paragraph[0].replace(b'pageBreak="0"',b'pageBreak="1"',1).replace(b'id="0"',b'id="1"',1)
            repeated=re.sub(rb'<hp:secPr\b.*?</hp:secPr>',b'',repeated,flags=re.S)
            repeated=re.sub(rb'<hp:ctrl\b.*?</hp:ctrl>',b'',repeated,flags=re.S)
            data=data.replace(b'</hs:sec>',repeated+b'</hs:sec>')
        target.writestr(entry,data)
