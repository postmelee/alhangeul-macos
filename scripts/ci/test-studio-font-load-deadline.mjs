import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import {resolve} from 'node:path';
import vm from 'node:vm';
import {adaptFontLoader} from '../studio-font-load-adapter.mjs';
const upstream = process.argv[2];
if (!upstream) throw Error('upstream checkout argument required');
const original = readFileSync(resolve(upstream, 'rhwp-studio/src/core/font-loader.ts'), 'utf8');
const code = stripTypeScriptTypes(adaptFontLoader(original)).replace(/import \{([\s\S]*?)\} from '\.\/font-rule-runtime.ts';/, 'const {$1} = require();').replace(/export /g, '') + '\nObject.assign(exports, {loadWebFonts, getWebFontSupplySnapshot});';
function setup(mode) {
  const timers = new Map(), faces = [], added = [], styles = new Map();
  let id = 0;
  class Face {
    constructor(family) {this.family=family;faces.push(this);}
    load() {
      if (mode === 'success') return Promise.resolve(this);
      if (mode === 'failure') return Promise.reject(Error('network'));
      return new Promise((resolve,reject)=>{this.resolve=()=>resolve(this);this.reject=reject;});
    }
  }
  const exports = {};
  vm.runInNewContext(code, {exports, FontFace:Face, console:{log(){},debug(){}},
    setTimeout(fn){const key=++id;timers.set(key,fn);return key;},clearTimeout(key){timers.delete(key);},
    document:{body:null,fonts:{check:()=>false,add:face=>added.push(face)},
      getElementById:id=>styles.get(id),createElement:()=>({textContent:''}),head:{appendChild:s=>styles.set(s.id,s)}},
    require:()=>({FONT_RULE_WEBFONT_ENTRIES:[{name:'함초롬바탕',file:'https://fonts.invalid/a.woff2'}],
      normalizeProjectedFontFamily:s=>s.toLowerCase(),projectedSubstituteTargets:()=>[],
      isCanvasKitSfntPlanned:()=>false,getProjectedWebFontRuleIds:()=>[]})});
  return {api:exports,timers,faces,added,styles};
}
for (const mode of ['success','failure','pending']) {
  const state=setup(mode), progress=[];
  const loading=state.api.loadWebFonts([], (n,total)=>progress.push([n,total]));
  if (mode==='pending') for(const fn of [...state.timers.values()]) fn();
  await loading;
  assert.equal(state.timers.size,0);
  assert.equal(state.added.length,mode==='success'?1:0);
  assert.deepEqual(progress,[[1,1]]);
  const css=state.styles.get('rhwp-web-font-faces').textContent;
  assert.equal(css.includes('https://'),mode==='success');
  assert.equal(state.api.getWebFontSupplySnapshot('함초롬바탕').status,mode==='success'?'loaded':'catalogued');
  if(mode==='pending') {
    state.faces[0].resolve();await Promise.resolve();await Promise.resolve();
    assert.equal(state.added.length,0); // 지연 성공은 이미 시작한 문서의 metrics를 바꾸지 않는다.
    await state.api.loadWebFonts();assert.equal(state.faces.length,1);
  }
  console.log('PASS '+mode+' font load, CSS supply, progress and timer cleanup');
}
const disabled=setup('pending');await disabled.api.loadWebFonts([],undefined,{disableExternalWebFonts:true});
assert.equal(disabled.faces.length,0);console.log('PASS external-font disabled option');
assert.throws(()=>adaptFontLoader(original.replace('const result = await face.load();','changed();')));
console.log('PASS source drift fails build');
