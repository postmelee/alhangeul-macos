"""동일 PS의 원본 변경을 검사하는 개인 검증 파일. 기존 입력은 수정하지 않는다."""
import sys
from pathlib import Path
from fontTools.ttLib import TTFont
source, target = map(Path, sys.argv[1:3])
if target.exists():
    raise SystemExit('새 출력 경로를 지정해 주세요')
font = TTFont(source, recalcTimestamp=False)
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.transformPen import TransformPen
glyph_name = font.getBestCmap()[ord('한')]
glyph_set = font.getGlyphSet()
pen = TTGlyphPen(glyph_set)
# 첫 양성 문서의 '한'을 가로로 줄인다. composite도 component transform을 보존한다.
glyph_set[glyph_name].draw(TransformPen(pen, (0.55, 0, 0, 1, 0, 0)))
font['glyf'][glyph_name] = pen.glyph()
for row in font['name'].names:
    if row.nameID == 5:
        row.string = 'Version 2.001; Private native acceptance'.encode(row.getEncoding())
font.save(target)
print('별도 검증 variant 생성 완료')
