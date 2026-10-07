const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const {stripTypeScriptTypes} = require('node:module');
const {pathToFileURL} = require('node:url');
const path = require('node:path');
const adapter = import(pathToFileURL(path.resolve(__dirname, '../studio-font-menu-adapter.mjs')));
const fonts = `export function getLocalFonts(options: GetLocalFontsOptions = {}): string[] {
  return normalizeFamilies(getLocalFontRecords(options).map(record => record.displayName));
}`;
const toolbar = `import { getLocalFonts } from '@/core/local-fonts';
    eventBus.on('local-fonts-changed', () => {
      this.refreshFontDropdown();
    });`;
test('활성 host family를 중복 제거하고 비활성 시 기존 browser 목록을 사용', async () => {
  const {adaptSource, sourcePaths} = await adapter;
  let active = true, records = [{family: '고운바탕'}, {family: '고운바탕'}, {family: '<글꼴 & 이름>'}];
  const source = stripTypeScriptTypes(adaptSource(fonts, sourcePaths[0]).replace('export ', ''));
  const get = vm.runInNewContext(source + '\ngetLocalFonts', {
    hasHostFontProvider: () => active, currentHostRecords: () => records,
    normalizeFamilies: names => [...new Set(names)],
    getLocalFontRecords: () => [{displayName: 'browser-font'}],
  });
  assert.deepEqual([...get()], ['고운바탕', '<글꼴 & 이름>']);
  records = []; assert.deepEqual([...get()], []); // 공급 불가능한 browser 후보를 섞지 않는다.
  active = false; assert.deepEqual([...get()], ['browser-font']);
});
test('변경 직후 이전 메뉴 폐기, 지연 snapshot 완료 시 새 메뉴 갱신, 오래된 세대 무시', async () => {
  const {adaptSource, sourcePaths} = await adapter;
  const code = adaptSource(toolbar, sourcePaths[1]);
  const registration = code.slice(code.indexOf('    onHostFontsChanged'));
  let generation = 1, notify, finish, closed = 0, painted = 0;
  const owner = {fontMenu: {}, closeFontMenu() { closed++; this.fontMenu = null; }, renderFontMenu() { painted++; }};
  vm.runInNewContext('(function(){' + registration + '}).call(owner)', {
    owner, onHostFontsChanged: callback => { notify = callback; },
    getHostFontState: () => ({generation}),
    prepareHostFontCatalog: () => new Promise(resolve => { finish = resolve; }),
  });
  notify(); assert.equal(closed, 1); assert.equal(owner.fontMenu, null);
  owner.fontMenu = {}; finish(); await new Promise(resolve => setImmediate(resolve));
  assert.equal(painted, 1);
  notify(); owner.fontMenu = {}; generation++; finish(); await new Promise(resolve => setImmediate(resolve));
  assert.equal(painted, 1);
});
test('upstream 확장 지점 변경·중복은 빌드를 실패시키며 대상 이외 파일을 변환하지 않음', async () => {
  const {adaptSource, fontMenuPlugin, sourcePaths} = await adapter;
  assert.throws(() => adaptSource(fonts.replace('getLocalFonts', 'newAPI'), sourcePaths[0]), /adapter drift/);
  assert.throws(() => adaptSource(fonts + fonts, sourcePaths[0]), /adapter drift/);
  assert.throws(() => adaptSource(toolbar.replace("'local-fonts-changed'", "'changed'"), sourcePaths[1]), /adapter drift/);
  const row = {path: sourcePaths[0], absolute: '/source.ts', original: fonts, adapted: adaptSource(fonts, sourcePaths[0])};
  const plugin = fontMenuPlugin([row], {});
  assert.equal(plugin.transform('untouched', '/other.ts'), undefined);
  assert.throws(() => plugin.transform(fonts + '//late change', '/source.ts'), /source changed/);
  assert.equal(plugin.transform(fonts, '/source.ts').code, row.adapted);
  assert.throws(() => plugin.generateBundle.call({emitFile() {}}), /not included/);
});
