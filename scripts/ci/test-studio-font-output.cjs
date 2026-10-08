const {test} = require('node:test');
const assert = require('node:assert/strict');
const {stripTypeScriptTypes} = require('node:module');
const {pathToFileURL} = require('node:url');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const adapter = import(pathToFileURL(path.resolve(__dirname, '../studio-font-menu-adapter.mjs')));

test('출력 wrapper는 공식 matcher를 그대로 호출하고 ID/revision/generation만 반환', async () => {
  const {outputResolverSource} = await adapter;
  let generation = 1, reads = 0;
  const calls = [];
  const regular = {hostReference: {face: {id:'native-r', postscriptName:'Font-R', weight:400, slant:'normal'}}};
  const bold = {hostReference: {face: {id:'native-b', postscriptName:'Font-B', weight:700, slant:'normal'}}};
  const api = vm.runInNewContext(stripTypeScriptTypes(outputResolverSource.replace('export ', '')) + '\nresolveHostOutputFonts', {
    hasHostFontProvider: () => true, prepareHostFontCatalog: async () => {},
    getHostFontState: () => ({active:true, generation, lastError:null}), currentHostRecords: () => {},
    hostFontSource: {references: () => [{revision:'r1'}]},
    hostLookup: {aliases:new Map([['ambiguous',[]]])}, normalizeFontAlias: name => name,
    resolveRendererLocalFont: (family, style) => {
      calls.push([family, style.weight, style.slant]);
      return family === 'Font' ? (style.weight === 700 ? bold : regular) : null;
    }, readFace: () => { reads++; },
  });
  const request = (key, family, weight) => ({key, family, weight, slant:'normal'});
  const result = await api([request('a','Font',400), request('b','Font',700),request('c','absent',400),request('d','ambiguous',400)]);
  assert.equal(result.generation, 1); assert.equal(result.revision, 'r1');
  assert.deepEqual(result.selections.map(r => r.status).join(','), 'selected,selected,absent,unavailable');
  assert.equal(result.selections[0].id, 'native-r'); assert.equal(result.selections[1].id, 'native-b');
  assert.equal(reads, 0); assert.equal(calls.length, 4);
  await assert.rejects(api([request('same','Font',400),request('same','Font',700)]));
  await assert.rejects(api([request('key','Font',NaN)]));
  await assert.rejects(api(Array.from({length:2049},(_,i)=>request(String(i),'Font',400))));
});

test('main adapter만 추가 API를 노출하며 pinned anchor 중복/변경은 실패', async () => {
  const {adaptSource,sourcePaths} = await adapter;
  const source = "import { setHostFontProvider, getHostFontState } from '@/core/local-fonts';\nfonts: { setProvider: setHostFontProvider, getState: getHostFontState },";
  assert.match(adaptSource(source,sourcePaths[3]), /resolveOutputRequests: resolveHostOutputFonts/);
  assert.throws(()=>adaptSource(source+source,sourcePaths[3]), /adapter drift/);
  assert.throws(()=>adaptSource(source.replace('fonts:', 'other:'),sourcePaths[3]), /adapter drift/);
});

test('출력 bridge는 native catalog identity에 묶고 빈 catalog와 실제 세대 변경을 구분', async () => {
  const swift = fs.readFileSync(path.resolve(__dirname,'../../Sources/HostApp/Services/RhwpStudioOutputFontBridgeScript.swift'),'utf8');
  const source = swift.match(/static let resolve = #"""\n([\s\S]*?)\n    """#/)[1];
  const execute = (result, context, generation) => vm.runInNewContext('(async()=>{'+source+'})()', {
    requests:[{key:'a'}], window:{rhwpStudio:{fonts:{resolveOutputRequests:async()=>result,getState:()=>({generation})}},
      __alhangeulFontConnection:{getOutputContext:()=>context}},
  });
  const context = {identity:'native',revision:'r1',unavailable:['a']};
  const raw = await execute({generation:1,revision:null,selections:[{key:'a',status:'absent'}]},context,1);
  const value = JSON.parse(raw);
  assert.equal(value.identity,'native');assert.equal(value.selections[0].status,'unavailable');
  await assert.rejects(execute({generation:1,revision:'old',selections:[]},context,1));
  await assert.rejects(execute({generation:1,revision:'r1',selections:[]},context,2));
  await assert.rejects(execute({generation:1,revision:null,selections:[]},null,1));
});
