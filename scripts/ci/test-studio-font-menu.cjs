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
const options = `function createFontPanel() {
    const panel = document.createElement('div');
    panel.appendChild(document.createElement('recent-fonts'));
    panel.appendChild(document.createElement('font-sets'));
    // ── 로컬 글꼴 섹션 ──
    browserCalls++;
    panel.appendChild(document.createElement('browser-fonts'));
    return panel;
}`;
test('native 환경설정은 Mac 안내와 native 진입점만 사용하고 browser 환경은 기존 경로 유지', async () => {
  const {adaptSource, sourcePaths} = await adapter;
  const commands = [], window = {};
  const context = vm.createContext({window, browserCalls: 0, document: {createElement(tag) {
    return {tag, dataset: {}, children: [], append(...items) { this.children.push(...items); },
      appendChild(item) { this.append(item); }, addEventListener(event, callback) { this[event] = callback; }};
  }}});
  const code = stripTypeScriptTypes(adaptSource(options, sourcePaths[2]));
  vm.runInContext(code, context);
  window.__alhangeulHostBridgeRunNativeCommand = command => { commands.push(command); return true; };
  const native = context.createFontPanel();
  assert.equal(context.browserCalls, 0);
  assert.deepEqual(native.children.map(row => row.tag), ['recent-fonts', 'font-sets', 'div']);
  const section = native.children[2];
  assert.equal(section.children[0].textContent, 'Mac 글꼴');
  assert.match(section.children[1].textContent, /상단 글꼴 목록/);
  assert.equal(section.children[2].textContent, '글꼴 설정 열기…');
  section.children[2].click();
  assert.deepEqual(commands, ['app:font-settings']);
  delete window.__alhangeulHostBridgeRunNativeCommand;
  const browser = context.createFontPanel();
  assert.equal(context.browserCalls, 1);
  assert.equal(browser.children[2].tag, 'browser-fonts');
  assert.throws(() => adaptSource(options.replace('로컬 글꼴 섹션', '새 글꼴 섹션'), sourcePaths[2]), /adapter drift/);
});
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
