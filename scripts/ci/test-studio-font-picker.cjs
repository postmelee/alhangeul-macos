const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.join(__dirname, '../..');
const raw = name => fs.readFileSync(path.join(root, 'Sources/HostApp/Services', name), 'utf8')
  .match(/static let source = #"""\n([\s\S]*?)\n    """#/)[1];
const factory = vm.runInThisContext(raw('StudioFontPickerScript.swift'));
const tick = () => new Promise(resolve => setImmediate(resolve));
class Node {
  constructor(tag, document) { this.tag = tag; this.document = document; this.children = []; this.listeners = {}; this.value = ''; }
  appendChild(child) { this.children.push(child); child.parent = this; return child; }
  replaceChildren() { this.children = []; }
  setAttribute() {}
  addEventListener(name, listener) { (this.listeners[name] ||= []).push(listener); }
  fire(name, extra = {}) { for (const listener of this.listeners[name] || []) listener({target: this, preventDefault() {}, ...extra}); }
  focus() { this.document.activeElement = this; }
  remove() { if (this.parent) this.parent.children = this.parent.children.filter(c => c !== this); }
  get options() { return this.children; }
  all(tag) { return [...(this.tag === tag ? [this] : []), ...this.children.flatMap(c => c.all(tag))]; }
}
function fixture() {
  const document = {createElement: tag => new Node(tag, document)};
  document.body = new Node('body', document);
  const commands = new Map(), listeners = new Set(), menu = [], applied = [];
  const state = {generation: 1, revision: 'r1', hasDocument: true, hasSelection: true, isEditable: true, isFormMode: false};
  const input = {getSelection: () => ({start: {para: 2, pos: 3}, end: {para: 2, pos: 8}}),
    applyCharPropsToRange: (...args) => applied.push(args), focus() {}};
  const services = {wasm: {get documentGeneration() { return state.generation; },
    findOrCreateFontId: family => family === '고운바탕' ? 12 : 13}, getInputHandler: () => input};
  const snapshot = () => Promise.resolve({revision: state.revision,
    faces: [{family: '고운바탕', weight: 400}, {family: '고운바탕', weight: 700}, {family: '<unsafe font>'}]});
  const provider = {getSnapshot: snapshot, subscribe(fn) { listeners.add(fn); return () => listeners.delete(fn); }};
  const automation = {registerCommand: def => commands.set(def.id, def), unregisterCommand: id => commands.delete(id),
    addMenuItem: spec => menu.push(spec), execute(id, params, options = {}) {
      const command = commands.get(id);
      if (command.opensDialog && !options.allowDialog) return {ok: false, reason: 'needs-dialog'};
      if (!command.canExecute(state)) return {ok: false, reason: 'disabled'};
      command.execute(services, params); return {ok: true};
    }};
  const picker = factory({adapter: {provider}, getAutomation: () => automation, document});
  return {picker, document, automation, commands, state, menu, listeners, applied,
    open: () => automation.execute('ext:alhangeul-local-font-picker', {}, {allowDialog: true})};
}

test('공개 확장 command로만 설치하고 기본 자동화는 dialog를 열지 않음', () => {
  const f = fixture(); assert.equal(f.picker.install(), true); f.picker.install();
  assert.equal(f.commands.size, 2); assert.equal(f.menu.length, 1);
  assert.deepEqual(f.automation.execute('ext:alhangeul-local-font-picker'), {ok: false, reason: 'needs-dialog'});
  assert.equal(f.document.body.children.length, 0); f.picker.dispose();
});
test('family를 중복 제거·검색하고 원래 이름으로 캡처한 선택 영역에 적용', async () => {
  const f = fixture(); f.picker.install(); f.open(); await tick();
  const overlay = f.document.body.children[0];
  const search = overlay.all('input')[0], list = overlay.all('select')[0];
  assert.equal(list.options.length, 2);
  assert.equal(list.options.some(n => n.textContent === '<unsafe font>'), true);
  search.value = '고운'; search.fire('input');
  assert.equal(list.options.length, 1); assert.equal(list.options[0].value, '고운바탕');
  list.value = '고운바탕'; list.fire('change');
  overlay.all('button')[1].fire('click'); await tick();
  assert.deepEqual(f.applied, [[{para: 2, pos: 3}, {para: 2, pos: 8}, {fontId: 12}]]);
  assert.equal(f.document.body.children.length, 0); f.picker.dispose();
});
test('읽기 전용·양식 제한·객체 선택 상태에서 편집 진입을 거부', () => {
  for (const state of [{hasSelection: false}, {isEditable: false}, {isFormMode: true, canEditFormField: false},
    {inCellSelectionMode: true}, {inTableObjectSelection: true}, {inPictureObjectSelection: true}]) {
    const f = fixture(); f.picker.install(); Object.assign(f.state, state);
    assert.equal(f.open().ok, false); assert.equal(f.document.body.children.length, 0); f.picker.dispose();
  }
});
test('dialog 이후 읽기 전용 전환·문서 교체·catalog 교체는 이전 영역에 쓰지 않음', async () => {
  for (const change of [f => { f.state.isEditable = false; }, f => { f.state.generation++; },
    f => { f.state.revision = 'r2'; for (const notify of f.listeners) notify(); }]) {
    const f = fixture(); f.picker.install(); f.open(); await tick();
    const overlay = f.document.body.children[0], list = overlay.all('select')[0];
    list.value = '고운바탕'; list.fire('change'); change(f);
    overlay.all('button')[1].fire('click'); await tick();
    assert.equal(f.applied.length, 0); f.picker.dispose();
  }
});
test('변경 알림 전 revision이 바뀌면 오래된 선택 창을 닫고 쓰지 않음', async () => {
  const f = fixture(); f.picker.install(); f.open(); await tick();
  const overlay = f.document.body.children[0], list = overlay.all('select')[0];
  list.value = '고운바탕'; list.fire('change'); f.state.revision = 'r2';
  overlay.all('button')[1].fire('click'); await tick();
  assert.equal(f.applied.length, 0); assert.equal(f.document.body.children.length, 0); f.picker.dispose();
});
test('Escape·취소·dispose는 dialog와 자신이 등록한 command를 정리', async () => {
  const f = fixture(); f.picker.install(); f.open(); await tick();
  f.document.body.children[0].fire('keydown', {key: 'Escape'});
  assert.equal(f.document.body.children.length, 0);
  f.open(); await tick(); f.picker.dispose();
  assert.equal(f.commands.size, 0); assert.equal(f.listeners.size, 0);
  assert.equal(f.document.body.children.length, 0);
});

test('제품 bootstrap은 늦은 API 준비 이후 연결하고 pagehide에서 해제', async () => {
  const swift = fs.readFileSync(path.join(root, 'Sources/HostApp/Services/StudioFontProviderScript.swift'), 'utf8');
  const bootstrap = swift.match(/static var bootstrapSource:[\s\S]*?"""\n([\s\S]*?)\n        """/)[1]
    .replace('\\(source)', raw('StudioFontProviderScript.swift'))
    .replace('\\(StudioFontPickerScript.source)', raw('StudioFontPickerScript.swift'));
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
  assert.equal(registered.length, 2);
  assert.equal(native.every(m => m.loadToken === 'current-token'), true);
  const first = await currentProvider.getSnapshot(new AbortController().signal);
  window.__alhangeulFontConnection.refresh();
  const next = await currentProvider.getSnapshot(new AbortController().signal);
  assert.notEqual(next.revision, first.revision);
  window.dispatchEvent(new Event('pagehide')); await tick();
  assert.equal(window.__alhangeulFontConnection.getState().status, 'disposed');
  assert.equal(currentProvider, null);
});
