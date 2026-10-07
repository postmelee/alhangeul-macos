// 실제 번들 WASM으로 시험 문서를 만들고 저장 결과의 이름/굵기 보존을 확인한다.
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, copyFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
const [mode, bundle, output] = process.argv.slice(2);
const modulePath = resolve(output, 'probe-rhwp.mjs');
copyFileSync(resolve(bundle, 'rhwp.js'), modulePath);
const {initSync, HwpDocument} = await import(pathToFileURL(modulePath));
initSync({module: readFileSync(resolve(bundle, 'rhwp_bg.wasm'))});
const text = '한글 가나다 ABC 0123 고운바탕 글꼴 확인';
if (mode === 'create') {
  const doc = HwpDocument.createEmpty();
  try {
    doc.createBlankDocument(); doc.insertText(0, 0, 0, text);
    doc.applyCharFormat(0, 0, 0, text.length, JSON.stringify({fontId: doc.findOrCreateFontId('Gowun Batang'), fontSize: 2400}));
    doc.applyCharFormat(0, 0, 3, 6, JSON.stringify({bold: true}));
    // 선택 창이 기존 글꼴과 다른 이름으로 실제 문서 데이터를 바꾸는지 확인한다.
    doc.applyCharFormat(0, 0, text.length - 2, text.length, JSON.stringify({fontId: doc.findOrCreateFontId('돋움')}));
    writeFileSync(resolve(output, 'gowun-document.hwp'), doc.exportHwp());
    writeFileSync(resolve(output, 'gowun-document.hwpx'), doc.exportHwpx());
  } finally { doc.free(); }
} else if (mode === 'verify') {
  const proof = [];
  for (const ext of ['hwp', 'hwpx']) {
    const doc = new HwpDocument(readFileSync(resolve(output, `picker-result.${ext}`)));
    try {
      for (const offset of [0, 3, text.length - 2]) {
        const props = JSON.parse(doc.getCharPropertiesAt(0, 0, offset));
        assert.equal(props.fontFamily, 'Gowun Batang');
        assert.equal(props.bold, offset === 3);
        assert(props.fontFamilies.every(f => f === 'Gowun Batang'));
        proof.push({ext, offset, fontFamily: props.fontFamily, bold: props.bold});
      }
      assert(!doc.renderPageSvg(0).includes('__rhwp_host_face_'));
    } finally { doc.free(); }
  }
  writeFileSync(resolve(output, 'saved-font-proof.json'), JSON.stringify(proof, null, 2) + '\n');
  console.log('PASS: saved HWP/HWPX reopened; original family, Regular/Bold, changed tail; no renderer alias');
} else throw new Error('Expected create or verify');
