#!/usr/bin/env python3
"""테스트 전용 기하 도형 글꼴 생성. 재생성에만 fontTools 4.59.1 필요."""
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.ttLib import TTFont, TTCollection, newTable
from fontTools.ttLib.tables._f_v_a_r import Axis, NamedInstance
from fontTools.ttLib.tables.TupleVariation import TupleVariation

ROOT = Path(__file__).parent
GLYPHS = ['.notdef', 'A', 'ga']


def outline(pen):
    pen.moveTo((100, 0))
    pen.lineTo((100, 600))
    pen.lineTo((500, 600))
    pen.lineTo((500, 0))
    pen.closePath()


def build(name, bold=False, cff=False):
    fb = FontBuilder(1000, isTTF=not cff)
    fb.setupGlyphOrder(GLYPHS)
    fb.setupCharacterMap({0x41: 'A', 0xAC00: 'ga'})
    if cff:
        chars = {}
        for glyph in GLYPHS:
            pen = T2CharStringPen(600, None)
            outline(pen)
            chars[glyph] = pen.getCharString()
        fb.setupCFF(name, {'FullName': name, 'FamilyName': 'Alhangeul Fixture'}, chars, {})
    else:
        glyphs = {}
        for glyph in GLYPHS:
            pen = TTGlyphPen(None)
            outline(pen)
            glyphs[glyph] = pen.glyph()
        fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics({g: (600, 100) for g in GLYPHS})
    fb.setupHorizontalHeader(ascent=800, descent=-200)
    style = 'Bold' if bold else 'Regular'
    fb.setupNameTable({'familyName': 'Alhangeul Fixture', 'styleName': style,
                      'fullName': 'Alhangeul Fixture ' + style, 'psName': name,
                      'uniqueFontIdentifier': name + '-1', 'version': 'Version 1.000'})
    fb.font['name'].setName('알한글 검증 글꼴', 1, 3, 1, 0x0412)
    fb.font['name'].setName('굵게' if bold else '보통', 2, 3, 1, 0x0412)
    fb.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800,
                usWinDescent=200, usWeightClass=700 if bold else 400,
                fsSelection=0x20 if bold else 0x40, fsType=0)
    fb.setupPost()
    fb.font['head'].macStyle = 1 if bold else 0
    fb.font['head'].created = fb.font['head'].modified = 3800000000
    fb.font.recalcTimestamp = False
    return fb.font


regular = build('AlhangeulFixture-Regular')
regular.save(ROOT / 'regular.ttf')
bold = build('AlhangeulFixture-Bold', bold=True)
bold.save(ROOT / 'bold.ttf')
build('AlhangeulFixtureCFF-Regular', cff=True).save(ROOT / 'regular.otf')
collection = TTCollection()
collection.fonts = [regular, bold]
collection.save(ROOT / 'two-face.ttc')
variable = build('AlhangeulFixtureVariable-Regular')
variable['fvar'] = newTable('fvar')
axis = Axis()
axis.axisTag, axis.minValue, axis.defaultValue, axis.maxValue = 'wght', 100, 400, 900
axis.flags, axis.axisNameID = 0, 256
variable['fvar'].axes = [axis]
variable['name'].setName('Weight', 256, 3, 1, 0x0409)
variable['name'].setName('Bold', 257, 3, 1, 0x0409)
variable['name'].setName('AlhangeulFixtureVariable-Bold', 258, 3, 1, 0x0409)
instance = NamedInstance()
instance.subfamilyNameID, instance.postscriptNameID = 257, 258
instance.coordinates = {'wght': 700}
variable['fvar'].instances = [instance]
variable['gvar'] = newTable('gvar')
variable['gvar'].variations = {
    glyph: [TupleVariation({'wght': (0, 1, 1)}, [(0, 0), (0, 0), (100, 0), (100, 0)] + [(0, 0)] * 4)]
    for glyph in GLYPHS
}
variable.save(ROOT / 'variable.ttf')

# format 1 language-tag 레코드: 한국어 이름은 ko-KR 태그로 연결한다.
import struct
from fontTools.ttLib.tables.DefaultTable import DefaultTable
font = build('AlhangeulFixtureLanguage-Regular')
raw = font['name'].compile(font)
_, count, storage = struct.unpack_from('>HHH', raw)
records = bytearray(raw[6:storage])
for i in range(count):
    if struct.unpack_from('>H', records, i * 12 + 4)[0] == 0x0412:
        struct.pack_into('>H', records, i * 12 + 4, 0x8000)
tag = 'ko-KR'.encode('utf-16-be')
strings = raw[storage:]
lang_records = struct.pack('>HHH', 1, len(tag), len(strings))
name_table = DefaultTable('name')
name_table.data = struct.pack('>HHH', 1, count, storage + 6) + records + lang_records + strings + tag
font['name'] = name_table
font.save(ROOT / 'language-tag.ttf')
