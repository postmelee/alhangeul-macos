// 고정 upstream 소스는 수정하지 않는다. 이 adapter는 실험에서만 queryLocalFonts를 제공한다.
import { detectLocalFonts, loadStoredLocalFonts, getLocalFontRecords, resolveLocalFont,
  loadLocalFontBytesFor, localFontFaceKey } from '@rhwp/core/local-fonts.ts';
import { CanvasKitLayerRenderer } from '@rhwp/view/canvaskit-renderer.ts';
const native = (op, more = {}) => window.webkit.messageHandlers.native.postMessage({op, ...more});
const assert = (ok, message) => { if (!ok) throw Error(message); };
let enumeration = 0, queries = 0, reads = 0;
const counts = () => ({enumeration, queries, reads});
const phase = (value, fault = 'none') => native('phase', {value, fault});
async function run() {
  globalThis.chrome = {storage: {local: {
    get: () => native('get'), set: items => native('set', {items}), remove: async () => {},
  }}};
  const catalog = await native('catalog');
  let enumerationOverride = null;
  // metadata 열거에는 blob을 주지 않는다. 실제 바이트 요청에만 공급한다.
  globalThis.queryLocalFonts = async options => {
    if (!options?.postscriptNames) { enumeration++; return enumerationOverride ?? catalog; }
    queries++;
    return catalog.filter(r => options.postscriptNames.includes(r.postscriptName)).map(r => ({...r,
      blob: async () => { reads++; const b64 = await native('read', {id:r.id});
        return new Blob([Uint8Array.from(atob(b64), c => c.charCodeAt(0))]); }
    }));
  };
  const restored = !!await loadStoredLocalFonts();
  await phase(restored ? 'relaunch' : 'cold');
  await detectLocalFonts({includeRegistered:true});
  const records = getLocalFontRecords({includeRegistered:true});
  assert(records.length === 2, 'two active faces');
  const names = catalog.map(r => r.postscriptName);
  const resolved = names.map(n => resolveLocalFont(n));
  assert(resolved.every((r,i) => r?.postscriptName === names[i]), 'exact PS match');
  assert(resolveLocalFont('Task565 Missing Face') === null, 'missing lookup');
  const family = catalog[0].family;
  const ambiguous = resolveLocalFont(family);
  assert(catalog[0].family === catalog[1].family && ambiguous === null, 'ambiguous family must not pick a style');
  const css = await Promise.all(names.map(async (n,i) => {
    try { const f = await new FontFace(`ProbeCSS${i}`, `local("${n}")`).load(); return {name:n, status:f.status}; }
    catch { return {name:n, status:'unavailable'}; }
  }));
  const renderer = await CanvasKitLayerRenderer.create('default', 'software');
  const before = counts();
  const prepared = await renderer.prepareLocalFonts(names);
  assert(prepared === 2, 'two CanvasKit faces');
  const afterCold = counts();
  await phase('warm');
  assert(await renderer.prepareLocalFonts(names) === 0, 'warm cached');
  const afterWarm = counts();
  assert(afterWarm.reads === afterCold.reads, 'no warm reads');
  // private 메서드는 관찰용으로만 감싼다. 인수·반환·선택 로직은 바꾸지 않는다.
  const selections = [];
  let renderPhase = "normal";
  const original = renderer.findPreparedTypeface.bind(renderer);
  renderer.findPreparedTypeface = name => {
    const selected = original(name), record = resolveLocalFont(name);
    if (selected) selections.push({phase:renderPhase,requested:name, postscriptName:record?.postscriptName,
      faceKey:record ? localFontFaceKey(record) : null, family:selected.fontFamily,
      localObject:record ? renderer.localTypefaces.get(localFontFaceKey(record)) === selected : false});
    return selected;
  };
  const canvas = document.querySelector('canvas');
  const tree = {pageWidth:1000,pageHeight:300,profile:'screen',root:{kind:'leaf',
    bounds:{x:0,y:0,width:1000,height:300},ops:names.map((name,i) => ({type:'textRun',
      bbox:{x:30,y:35+i*105,width:930,height:70},baseline:48,
      text:`${i ? 'Bold' : 'Regular'} · 맥 설치 글꼴 확인 ABC 123`,
      style:{fontFamily:name,fontSize:36,color:'#172b4d',bold:i===1}}))}};
  renderer.renderPage(tree,canvas,1);
  assert(names.every(n => selections.some(s => s.postscriptName === n && s.localObject)), 'render uses exact local objects');
  const png = canvas.toDataURL('image/png');
  await phase('concurrent');
  const concurrentBefore = counts();
  await Promise.all([loadLocalFontBytesFor(names),loadLocalFontBytesFor(names)]);
  const concurrentAfter = counts();
  assert(concurrentAfter.reads-concurrentBefore.reads === 2, 'inflight coalescing');
  await phase('stale-before-reset','missing');
  const stale = await renderer.prepareLocalFonts(names);
  assert(stale===0 && renderer.localTypefaces.size===2,'existing renderer retains old local cache');
  const controls = [];
  for (const fault of ['missing','denied','corruptRaw','corrupt']) {
    renderer.resetDocumentResources();
    await phase(fault,fault);
    const registered = await renderer.prepareLocalFonts(names);
    const nativeObjects = [...renderer.localTypefaces.values()].map(v => ({hasTypeface:!!v.typeface, families:v.fontManager?.countFamilies(),family:v.fontFamily}));
    if (fault !== 'corruptRaw') assert(registered === 0 && renderer.localTypefaces.size === 0, `${fault}: no local face`);
    renderPhase = fault;
    renderer.renderPage(tree,canvas,1);
    controls.push({fault,registered,nativeObjects,localFaces:renderer.localTypefaces.size,renderCompleted:renderer.lastRenderCompleted,fallbacks:renderer.diagnostics().fontSubstitutions});
    assert(renderer.lastRenderCompleted, `${fault}: fallback render`);
  }
  renderer.resetDocumentResources(); await phase('recovery');
  assert(await renderer.prepareLocalFonts(names) === 2, 'recovery after reset');
  renderer.dispose();
  // 동일 PS의 버전 식별 정보가 upstream 정규화에서 보존되는지 합성 메타데이터 대조.
  const originalSnapshot = await native('get');
  enumerationOverride = [...catalog, {...catalog[0], id:'duplicate-version', fullName:'Task565 Duplicate Version', version:'999'}];
  await phase('duplicate-metadata');
  await detectLocalFonts({force:true,includeRegistered:true});
  const duplicate = {input:enumerationOverride.length,output:getLocalFontRecords({includeRegistered:true}).length,
    selected:resolveLocalFont(catalog[0].postscriptName)};
  assert(duplicate.output === 2, 'upstream collapses same PS identity');
  await native('set',{items:originalSnapshot});
  await loadStoredLocalFonts();
  document.querySelector('p').textContent = '실제 설치 face 2종 연결·캐시·실패 대조 검증 완료';
  return {restored,records,resolved,ambiguous,css,before,afterCold,afterWarm,concurrentBefore,concurrentAfter,
    staleCacheRequiresReset:true, duplicate,controls,selections,png,counts:counts()};
}
run().then(result => native('finish',{result})).catch(e => native('finish',{failed:true,result:{error:String(e),stack:e.stack,counts:counts()}}));
