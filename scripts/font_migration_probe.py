#!/usr/bin/env python3
"""Task #563: OFL 파생 글꼴의 독립 복사·새 프로세스 WKWebView/PDF 검증.

글꼴과 고지 파일은 사용자가 명시한다. 제품 importer가 아닌 실험 fixture/runner다.
fontTools 4.59.1, macOS Swift/WebKit, pdffonts/pdftotext/pdftoppm이 필요하다.
"""
import argparse
import hashlib
import json
import pathlib
import platform
import shutil
import subprocess
import tempfile
import uuid


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def rename_font(font, family, style):
    """실험 복사본만 이름 변경. 저작권/라이선스 레코드는 보존한다."""
    ps = family + '-' + style
    replacements = {1: family, 2: style, 3: ps + '-Task563', 4: family + ' ' + style,
                    6: ps, 16: family, 17: style, 18: family + ' ' + style,
                    21: family, 22: style, 25: family}
    name = font['name']
    for record in list(name.names):
        if record.nameID in replacements:
            name.setName(replacements[record.nameID], record.nameID,
                         record.platformID, record.platEncID, record.langID)
    for name_id, value in replacements.items():
        name.setName(value, name_id, 3, 1, 0x409)
    if 'fvar' in font:
        for instance in font['fvar'].instances:
            if instance.postscriptNameID == 0xFFFF:
                continue
            instance_style = name.getDebugName(instance.subfamilyNameID).replace(' ', '')
            for record in list(name.names):
                if record.nameID == instance.postscriptNameID:
                    name.setName(family + '-' + instance_style, record.nameID,
                                 record.platformID, record.platEncID, record.langID)
    # name table만 바꾸면 CFF의 옛 PS 이름이 PDF에 나타날 수 있다.
    if 'CFF ' in font:
        cff = font['CFF '].cff
        cff.fontNames = [ps]
        for top in cff.topDictIndex:
            top.FamilyName = family
            top.FullName = family + ' ' + style
            if hasattr(top, 'FontName'):
                top.FontName = ps
            for fd in getattr(top, 'FDArray', []):
                if hasattr(fd, 'FontName'):
                    fd.FontName = ps
    return ps


def run(command, log=None, timeout=90, expected=0):
    try:
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        if log:
            output = error.stdout or b''
            log.write_text((output.decode(errors='replace') if isinstance(output, bytes) else output)
                           + '\nPROCESS TIMEOUT\n')
        raise
    if log:
        log.write_text(result.stdout)
    require(result.returncode == expected, '예상하지 않은 종료 코드: ' + str(command[0]) + '\n' + result.stdout[-3000:])
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ('ttf-regular', 'ttf-bold', 'otf-regular', 'otf-bold', 'ttf-license', 'otf-license'):
        parser.add_argument('--' + key, type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, help='저장소 build.noindex 아래 출력 부모 폴더')
    parser.add_argument('--variable', type=pathlib.Path, help='선택: 공식 Pretendard v1.3.9 가변 TTF')
    parser.add_argument('--variable-license', type=pathlib.Path, help='선택: 가변 TTF와 같은 태그의 OFL 고지')
    args = parser.parse_args()
    from fontTools.ttLib import TTFont, TTCollection
    import fontTools
    repo = pathlib.Path(__file__).resolve().parent.parent
    build = (repo / 'build.noindex').resolve()
    parent = (args.output or build / 'task563-font-migration').resolve()
    require(parent.is_relative_to(build), '출력은 이 저장소 build.noindex 아래여야 합니다.')
    inputs = {key: getattr(args, key).resolve(strict=True) for key in
              ('ttf_regular', 'ttf_bold', 'otf_regular', 'otf_bold', 'ttf_license', 'otf_license')}
    require(bool(args.variable) == bool(args.variable_license), '가변 TTF와 OFL을 함께 지정해야 합니다.')
    if args.variable:
        inputs['variable'] = args.variable.resolve(strict=True)
        inputs['variable_license'] = args.variable_license.resolve(strict=True)
    before = {key: sha(path) for key, path in inputs.items()}
    for key in (key for key in inputs if key.endswith('license')):
        require('SIL OPEN FONT LICENSE' in inputs[key].read_text(), 'OFL 고지 파일 필요: ' + key)
    for tool in ('xcrun', 'pdffonts', 'pdftotext', 'pdftoppm'):
        require(shutil.which(tool), '도구 필요: ' + tool)
    parent.mkdir(parents=True, exist_ok=True)
    root = pathlib.Path(tempfile.mkdtemp(prefix='run-', dir=parent))
    print('Evidence:', root, flush=True)
    source, managed = root / 'source', root / 'managed'
    source.mkdir()
    managed.mkdir()
    licenses = root / 'licenses'
    licenses.mkdir()
    for key in (key for key in inputs if key.endswith('license')):
        shutil.copyfile(inputs[key], licenses / (key + '.txt'))
    token = uuid.uuid4().hex[:12]
    faces = []
    metadata = []
    for kind in ('ttf', 'otf'):
        family = 'Task563' + token + kind.upper()
        for style, weight in (('Regular', 400), ('Bold', 700)):
            font = TTFont(inputs[kind + '_' + style.lower()], recalcTimestamp=False)
            require(('glyf' in font) if kind == 'ttf' else ('CFF ' in font), '입력 outline 형식 불일치')
            require('fvar' not in font, 'static regular/bold 입력이 필요합니다.')
            ps = rename_font(font, family, style)
            filename = kind + '-' + style + '.' + kind
            path = source / filename
            font.save(path)
            metadata.append({'id': filename, 'postScript': ps, 'sha256': sha(path),
                             'names': [{'id': n.nameID, 'platform': n.platformID, 'language': n.langID,
                                        'value': n.toUnicode()} for n in font['name'].names],
                             'fsType': font['OS/2'].fsType})
            font.close()
            faces.append({'id': 'face' + str(len(faces)), 'file': filename,
                          'sha256': sha(path), 'postScript': ps, 'weight': weight})
    collection = TTCollection()
    collection.fonts = [TTFont(source / f['file'], recalcTimestamp=False) for f in faces[:2]]
    collection.save(source / 'two-face.ttc')
    collection.close()
    for original in faces[:2]:
        faces.append({**original, 'id': 'face' + str(len(faces)), 'file': 'two-face.ttc',
                      'sha256': sha(source / 'two-face.ttc')})
    if args.variable:
        font = TTFont(inputs['variable'], recalcTimestamp=False)
        require('fvar' in font and len(font['fvar'].axes) == 1, '단일 wght 축 가변 TTF가 필요합니다.')
        axis = font['fvar'].axes[0]
        require((axis.axisTag, axis.minValue, axis.defaultValue, axis.maxValue) == ('wght', 45, 400, 930),
                '이 실험의 가변 범위는 공식 Pretendard v1.3.9 wght 45..930에 한정합니다.')
        family = 'Task563' + token + 'VAR'
        rename_font(font, family, 'Regular')
        path = source / 'variable.ttf'
        font.save(path)
        metadata.append({'id': path.name, 'sha256': sha(path), 'sfntFaces': 1,
                         'axes': {'wght': [45, 400, 930]}, 'namedInstances': len(font['fvar'].instances)})
        font.close()
        for style, weight in (('Regular', 400), ('Bold', 700)):
            faces.append({'id': 'face' + str(len(faces)), 'file': path.name, 'sha256': sha(path),
                          'postScript': family + '-' + style, 'weight': weight, 'variable': True})
    # 입력 분류 실험: 제품 충돌 UI/검증기 구현을 대신하지 않는다.
    duplicate = source / 'duplicate.ttf'
    shutil.copyfile(source / faces[0]['file'], duplicate)
    conflict = TTFont(duplicate, recalcTimestamp=False)
    glyph = conflict.getBestCmap()[ord('확')]
    advance, bearing = conflict['hmtx'].metrics[glyph]
    conflict['hmtx'].metrics[glyph] = (advance + 160, bearing)
    conflict.save(source / 'conflict.ttf')
    conflict.close()
    require(sha(duplicate) == faces[0]['sha256'], '중복 fixture 오류')
    conflict = TTFont(source / 'conflict.ttf')
    require(conflict['name'].getDebugName(6) == faces[0]['postScript'] and
            sha(source / 'conflict.ttf') != faces[0]['sha256'], '동명 충돌 fixture 오류')
    conflict.close()
    (source / 'truncated.ttf').write_bytes(duplicate.read_bytes()[:80])
    rejected = False
    try:
        broken = TTFont(source / 'truncated.ttf')
        broken.ensureDecompiled()
        broken.close()
    except Exception:
        rejected = True
    require(rejected, '잘린 글꼴이 파서에서 거부되지 않음')
    write_json(root / 'input-checks.json', {'sameBytes': 'duplicate', 'sameNameDifferentBytes': 'conflict',
                                         'truncated': 'rejected', 'hft': 'untested-no-real-fixture',
                                         'variable': 'prepared-wght-400-700' if args.variable else 'untested-no-isolated-variable-fixture'})
    for face in faces:
        shutil.copyfile(source / face['file'], managed / face['file'])
        require(sha(managed / face['file']) == face['sha256'], '복사 hash 불일치')
    write_json(root / 'manifest.json', {'faces': faces})
    write_json(root / 'metadata.json', metadata)
    write_json(root / 'provenance.json', {'inputHashes': before, 'fontTools': fontTools.__version__,
                                        'python': platform.python_version(), 'system': platform.platform(),
                                        'fixtureModification': 'Unique name/CFF names; conflict hmtx only. Originals unchanged.'})
    binary = root / 'FontMigrationProbe'
    write_json(root / 'original-preservation.json', {'before': before,
               'after': {key: sha(path) for key, path in inputs.items()},
               'equal': all(sha(path) == before[key] for key, path in inputs.items())})
    run(['xcrun', 'swiftc', '-warnings-as-errors', '-swift-version', '5', '-target', platform.machine() + '-apple-macosx12.0',
         '-module-cache-path', str(build / 'task563-module-cache'),
         str(repo / 'scripts/font_migration_probe.swift'), '-o', str(binary)], root / 'build.log', 180)
    results = []
    try:
        for label, mode in (('A-managed', 'present'), ('B-source-absent', 'present'), ('C-no-managed', 'missing')):
            if label.startswith('B'):
                # 이 실행에서 생성한 파생 fixture 디렉터리만 제거한다.
                shutil.rmtree(source)
            if label.startswith('C'):
                # 잘못된 관리 bytes를 공급하기 전에 hash 경계에서 거부해야 한다.
                target = managed / faces[0]['file']
                intact = target.read_bytes()
                tampered = root / 'D-tampered'
                tampered.mkdir()
                try:
                    target.write_bytes(intact[:80])
                    rejection = run([str(binary), str(root), str(tampered), 'present'], tampered / 'run.log', expected=1)
                    require('hashMismatch' in rejection and not (tampered / 'sample.pdf').exists(), '변조 bytes 거부 실패')
                finally:
                    target.write_bytes(intact)
                managed.rename(root / 'held-managed')
            output = root / label
            output.mkdir()
            run([str(binary), str(root), str(output), mode], output / 'run.log', 65)
            result = json.loads((output / 'result.json').read_text())
            result['pdfFonts'] = run(['pdffonts', str(output / 'sample.pdf')], output / 'pdffonts.txt')
            result['pdfText'] = run(['pdftotext', '-layout', str(output / 'sample.pdf'), '-'], output / 'text.txt')
            run(['pdftoppm', '-f', '1', '-singlefile', '-r', '72', '-png', str(output / 'sample.pdf'),
                 str(output / 'pdf')], output / 'pdf-raster.log')
            result['pdfRasterSHA256'] = sha(output / 'pdf.png')
            result['screenSHA256'] = sha(output / 'screen.png')
            results.append(result)
        a, b, c = results
        require(len({r['pid'] for r in results}) == 3, '서로 다른 프로세스 필요')
        for positive in (a, b):
            for index in list(range(4)) + (list(range(6, 8)) if args.variable else []):
                face = faces[index]
                require(positive['rows'][index]['load'] == 'fulfilled', '글꼴 로딩 실패')
                require(any(e.get('id') == face['id'] and e.get('sha256') == face['sha256']
                            for e in positive['resources']), '공급 hash 증거 누락')
                lines = [line.split() for line in positive['pdfFonts'].splitlines() if face['postScript'] in line]
                # pdffonts의 오른쪽 고정 열: emb sub uni object ID
                # WebKit은 한 face를 MacRoman과 한글 subset으로 나눌 수 있다.
                # 전부 임베딩, 한글용 ToUnicode 존재, 비 MacRoman subset의 매핑 및 전체 추출을 함께 검사한다.
                require(lines and all(line[-5] == 'yes' for line in lines)
                        and any(line[-3] == 'yes' for line in lines)
                        and all(line[-3] == 'yes' for line in lines if line[-6] != 'MacRoman'),
                        '선택 face의 PDF 임베딩/ToUnicode 누락: ' + face['id'])
            require(positive['pdfText'].count('한글 글꼴 독립 복사 확인 ABC 123') == len(faces), 'PDF 한글 추출 누락')
        require(a['rows'] == b['rows'] and a['descriptors'] == b['descriptors'], '재실행 화면/face 불일치')
        require(a['pdfRasterSHA256'] == b['pdfRasterSHA256'], '재실행 PDF 글리프 불일치')
        require(a['screenSHA256'] == b['screenSHA256'], '재실행 화면 snapshot 불일치')
        require(not any(e.get('status') == 'served' for e in c['resources']), '음성 대조군에서 글꼴 공급됨')
        require(all(r['load'] == 'rejected' for r in c['rows']), '음성 대조군의 로딩 성공 오인')
        require(token not in c['pdfFonts'], '음성 대조군 PDF에 실험 글꼴 존재')
        require(all(a['rows'][i]['rasterSHA256'] != c['rows'][i]['rasterSHA256'] for i in range(4)), 'fallback 화면 구별 실패')
        require(a['pdfRasterSHA256'] != c['pdfRasterSHA256'], 'fallback PDF 구별 실패')
        require(a['screenSHA256'] != c['screenSHA256'], 'fallback 화면 snapshot 구별 실패')
        if args.variable:
            require(a['rows'][6]['rasterSHA256'] != a['rows'][7]['rasterSHA256'], '가변 weight 차이 미검출')
            require(all(a['rows'][i]['rasterSHA256'] != c['rows'][i]['rasterSHA256'] for i in (6, 7)),
                    '가변 글꼴 fallback 구별 실패')
        summary = {'staticTTFOTF': 'PASS', 'freshProcesses': [r['pid'] for r in results],
                   'restartRowsEqual': True, 'restartScreenEqual': True, 'restartPDFRasterEqual': True,
                   'negativeControlDistinct': True, 'tamperedBytesRejected': True,
                   'variableWght400700': 'PASS' if args.variable else 'UNTESTED',
                   'rawTTC': [{'weight': faces[i + 4]['weight'], 'load': a['rows'][i + 4]['load'],
                               'matchesStandaloneFace': a['rows'][i + 4]['rasterSHA256'] == a['rows'][i]['rasterSHA256']}
                              for i in range(2)],
                   'limitations': ['not-product-Studio', 'not-signed-sandbox-AppGroup', 'not-QuickLook-Skia',
                                   'not-Hancom-license-or-uninstall', 'not-minimum-OS-runtime', 'not-real-HFT',
                                   'not-all-variable-axes-or-fonts']}
        write_json(root / 'summary.json', summary)
        print(json.dumps(summary, ensure_ascii=False, indent=2))
    finally:
        after = {key: sha(path) for key, path in inputs.items()}
        write_json(root / 'original-preservation.json', {'before': before, 'after': after, 'equal': before == after})
        require(before == after, '사용자 원본 hash가 변경됨')


if __name__ == '__main__':
    main()
