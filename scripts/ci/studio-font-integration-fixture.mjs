// 실제 번들 WASM으로 시험 문서를 만들고 저장 결과의 이름/굵기 보존을 확인한다.
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, copyFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
const [mode, bundle, output, suppliedFamily] = process.argv.slice(2);
const family = suppliedFamily || 'Gowun Batang';
const modulePath = resolve(output, 'probe-rhwp.mjs');
copyFileSync(resolve(bundle, 'rhwp.js'), modulePath);
const {initSync, HwpDocument} = await import(pathToFileURL(modulePath));
initSync({module: readFileSync(resolve(bundle, 'rhwp_bg.wasm'))});
const text = '한글 가나다 ABC 0123 고운바탕 글꼴 확인';
if (mode === 'create') {
  const doc = HwpDocument.createEmpty();
  try {
    doc.createBlankDocument(); doc.insertText(0, 0, 0, text);
    doc.applyCharFormat(0, 0, 0, text.length, JSON.stringify({fontId: doc.findOrCreateFontId(family), fontSize: 2400}));
    doc.applyCharFormat(0, 0, 3, 6, JSON.stringify({bold: true}));
    // 기존 메뉴 선택이 다른 이름의 문서 데이터를 실제로 바꾸는지 확인한다.
    doc.applyCharFormat(0, 0, text.length - 2, text.length, JSON.stringify({fontId: doc.findOrCreateFontId('돋움')}));
    writeFileSync(resolve(output, 'gowun-document.hwp'), doc.exportHwp());
    writeFileSync(resolve(output, 'gowun-document.hwpx'), doc.exportHwpx());
  } finally { doc.free(); }
} else if (mode === 'verify-live') {
  assert(suppliedFamily, '실제 설치 테스트 family를 지정해야 함');
  const proof = [];
  for (const ext of ['hwp','hwpx']) {
    const doc = new HwpDocument(readFileSync(resolve(output, `saved.${ext}`)));
    try {
      assert.equal(doc.getTextRange(0,0,0,doc.getParagraphLength(0,0)), text + ' 입력');
      for (const offset of [0,3,text.length-2,text.length+1]) {
        const props = JSON.parse(doc.getCharPropertiesAt(0,0,offset));
        assert.equal(props.fontFamily, family);
        assert.equal(props.bold, offset === 3);
        assert(props.fontFamilies.every(f => f === family));
        proof.push({ext,offset,fontFamily:props.fontFamily,bold:props.bold});
      }
      assert(!doc.renderPageSvg(0).includes('__rhwp_host_face_'));
    } finally { doc.free(); }
  }
  writeFileSync(resolve(output,'saved-font-proof.json'),JSON.stringify(proof,null,2)+'\n');
  console.log('PASS: 실제 설치 글꼴 적용·입력·저장 후 원래 family/style 재열기');
} else if (mode === 'verify-changes') {
  const proof=[];
  for(const ext of ['hwp','hwpx']) {
    const doc=new HwpDocument(readFileSync(resolve(output, `changes-result.${ext}`)));
    try {
      assert.equal(doc.getTextRange(0,0,0,doc.getParagraphLength(0,0)),text);
      for(const offset of [0,3,text.length-2]) {
        const props=JSON.parse(doc.getCharPropertiesAt(0,0,offset));
        assert.equal(props.fontFamily,offset===text.length-2 ? '돋움' : 'Gowun Batang');
        assert.equal(props.bold,offset===3);
        assert(props.fontFamilies.every(name=>name===props.fontFamily));
        proof.push({ext,offset,fontFamily:props.fontFamily,bold:props.bold});
      }
      assert(!doc.renderPageSvg(0).includes('__rhwp_host_face_'));
    } finally { doc.free(); }
  }
  writeFileSync(resolve(output,'changes-saved-proof.json'),JSON.stringify(proof,null,2)+'\n');
  console.log('PASS: native font changes preserve HWP/HWPX original content/names/styles on reopen');
} else if (mode === 'verify') {
  const proof = [];
  for (const ext of ['hwp', 'hwpx']) {
    const doc = new HwpDocument(readFileSync(resolve(output, `picker-result.${ext}`)));
    try {
      for (const offset of [0, 3, text.length - 2, text.length + 1]) {
        const props = JSON.parse(doc.getCharPropertiesAt(0, 0, offset));
        assert.equal(props.fontFamily, 'Gowun Batang');
        assert.equal(props.bold, offset === 3);
        assert(props.fontFamilies.every(f => f === 'Gowun Batang'));
        proof.push({ext, offset, fontFamily: props.fontFamily, bold: props.bold});
      }
      assert(doc.getTextRange(0,0,0,doc.getParagraphLength(0,0)).endsWith(' 입력'));
      assert(!doc.renderPageSvg(0).includes('__rhwp_host_face_'));
    } finally { doc.free(); }
  }
  writeFileSync(resolve(output, 'saved-font-proof.json'), JSON.stringify(proof, null, 2) + '\n');
  console.log('PASS: saved HWP/HWPX reopened; original family, Regular/Bold, changed tail; no renderer alias');
} else throw new Error('Expected create or verify');
