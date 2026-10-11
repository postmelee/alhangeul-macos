const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.join(__dirname, '../..');
const raw = name => fs.readFileSync(path.join(root, 'Sources/HostApp/Services', name), 'utf8')
  .match(/static let source = #"""\n([\s\S]*?)\n    """#/)[1];
const tick = () => new Promise(resolve => setImmediate(resolve));

test('제품 bootstrap은 늦은 API 준비 이후 연결하고 pagehide에서 해제', async () => {
  const swift = fs.readFileSync(path.join(root, 'Sources/HostApp/Services/StudioFontProviderScript.swift'), 'utf8');
  const bootstrap = swift.match(/static var bootstrapSource:[\s\S]*?"""\n([\s\S]*?)\n        """/)[1]
    .replace('\\(source)', raw('StudioFontProviderScript.swift'));
  const window = new EventTarget(), timers = [], native = [], registered = [];
  window.__alhangeulEditorLoad = {token: 'current-token'};
  window.webkit = {messageHandlers: {alhangeulFonts: {postMessage: async body => {
    native.push(body);
    if (body.op === 'handshake') return {version: 1, session: 's', revision: 'r'};
    if (body.op === 'catalog') return {faces: [], total: 0, nextOffset: 0, revision: 'r'};
    throw Error('unexpected bytes read');
  }}}};
  const document = {body: {}, createElement() { throw Error('No dialog should open'); }};
  const context = vm.createContext({window, document, AbortController, DOMException, setTimeout: fn => { timers.push(fn); return timers.length; },
    clearTimeout() {}, Date, atob});
  vm.runInContext(bootstrap, context);
  assert.equal(window.__alhangeulFontConnection.getState().status, 'waiting');
  let currentProvider;
  window.rhwpStudio = {fonts: {async setProvider(p) { currentProvider = p; if (p) await p.getSnapshot(new AbortController().signal); },
    getState: () => ({active: !!currentProvider})}, automation: {registerCommand: c => registered.push(c.id),
    addMenuItem() {}, unregisterCommand() {}, execute() {}}};
  timers.shift()(); await tick();
  assert.equal(window.__alhangeulFontConnection.getState().status, 'connected');
  assert.equal(registered.length, 0); // 별도 글꼴 command/menu를 추가하지 않는다.
  assert.equal(native.every(m => m.loadToken === 'current-token'), true);
  const first = await currentProvider.getSnapshot(new AbortController().signal);
  window.__alhangeulFontConnection.refresh();
  const next = await currentProvider.getSnapshot(new AbortController().signal);
  assert.notEqual(next.revision, first.revision);
  window.dispatchEvent(new Event('pagehide')); await tick();
  assert.equal(window.__alhangeulFontConnection.getState().status, 'disposed');
  assert.equal(currentProvider, null);
});
