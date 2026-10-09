const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// 실제 Swift raw string을 실행한다. 별도 JS 구현 복사본을 테스트하지 않는다.
const swift = fs.readFileSync(path.join(__dirname, '../../Sources/HostApp/Services/StudioFontProviderScript.swift'), 'utf8');
const source = swift.match(/static let source = #"""\n([\s\S]*?)\n    """#/)[1];
const factory = vm.runInThisContext(source);
const signal = () => new AbortController().signal;
const tick = () => new Promise(resolve => setImmediate(resolve));
const deferred = () => { let resolve; const promise = new Promise(r => { resolve = r; }); return {promise, resolve}; };
function face(id, changes = {}) {
  return {id, source: 'installed', family: `Family ${id}`, fullName: `Full ${id}`,
    postScriptName: `PS-${id}`, style: 'Regular', aliases: [], weight: null, traits: 0, ...changes};
}
function fixture(rows = [face('a')], overrides = {}) {
  const events = new EventTarget(), calls = [], transfers = new Map();
  const state = {token: 'load-1', revision: 'r1', rows, highWater: 0, bytes: Buffer.alloc(300000, 73)};
  let next = 0;
  async function transport(message) {
    calls.push(message);
    if (overrides.before) await overrides.before(message, state);
    if (message.loadToken !== state.token) throw new Error('staleSession');
    if (message.op === 'handshake') return {version: 1, session: 's1', revision: state.revision};
    if (message.session !== 's1' || message.revision !== state.revision) throw new Error('staleGeneration');
    switch (message.op) {
    case 'catalog': {
      const rows = state.rows.slice(message.offset, message.offset + 128);
      const result = {revision: state.revision, faces: rows, nextOffset: message.offset + rows.length, total: state.rows.length};
      return overrides.catalog ? overrides.catalog(result) : result;
    }
    case 'openFace': {
      if (transfers.size >= 2) throw new Error('busy');
      const row = state.rows.find(row => row.id === message.id);
      const id = `transfer-${++next}`;
      transfers.set(id, state.bytes);
      state.highWater = Math.max(state.highWater, transfers.size);
      const result = {id, revision: state.revision, byteCount: state.bytes.length, faceIndex: 0,
        sha256: 'a'.repeat(64), postScriptName: row.postScriptName, weight: row.weight || (row.style === 'Bold' ? 700 : 400)};
      return overrides.open ? overrides.open(result, message, state) : result;
    }
    case 'readChunk': {
      const data = transfers.get(message.id).subarray(message.offset, message.offset + message.length).toString('base64');
      const chunk = {id: message.id, revision: state.revision, offset: message.offset, data};
      return overrides.chunk ? overrides.chunk(chunk) : chunk;
    }
    case 'cancel': return {closed: true}; // 취소를 무시하는 I/O도 adapter가 회수해야 한다.
    case 'closeFace': transfers.delete(message.id); return {closed: true};
    default: throw Error('unexpected operation');
    }
  }
  let attached = null;
  const api = {async setProvider(provider) { attached = provider; if (provider) await provider.getSnapshot(signal()); },
    getState() { return {active: !!attached}; }};
  const adapter = factory({events, postMessage: transport, getLoadToken: () => state.token,
    getFontsAPI: () => overrides.noAPI ? undefined : api, delay: async () => {}});
  return {adapter, state, calls, transfers, events, api};
}
const cleanup = (t, f) => t.after(() => f.adapter.dispose());

test('출력 context는 native identity와 누락 후보를 제공하고 bytes 읽기 없이 갱신 때 폐기', async t => {
  const f = fixture([face('a'), face('b',{limitation:'disabled'}),
    face('c',{source:'managed',weight:400,limitation:'conflict'})], {
      catalog: result => ({...result,identity:'native-snapshot'}),
  }); cleanup(t,f);
  await f.adapter.connect();
  const value = f.adapter.getOutputContext([{key:'a',family:'Family a'},{key:'b',family:'Family b'},{key:'c',family:'Family c'}]);
  assert.equal(value.identity,'native-snapshot');
  assert.deepEqual(value.unavailable,['c']);
  assert.equal(f.calls.filter(c=>c.op==='openFace').length,0);
  f.adapter.refresh(); assert.equal(f.adapter.getOutputContext([]),null);
});

test('API 부재는 unsupported, native 읽기와 등록 없음', async t => {
  const f = fixture(undefined, {noAPI: true}); cleanup(t, f);
  assert.deepEqual(await f.adapter.connect(), {supported: false});
  assert.equal(f.calls.length, 0);
});
test('metadata 페이지 조회만으로 129 faces 준비, bytes는 지연 조회', async t => {
  const f = fixture(Array.from({length: 129}, (_, i) => face(`${i}`))); cleanup(t, f);
  assert.equal((await f.adapter.connect()).supported, true);
  const snapshot = await f.adapter.provider.getSnapshot(signal());
  assert.equal(snapshot.faces.length, 129);
  assert.equal(f.calls.filter(c => c.op === 'catalog').length, 2);
  assert.equal(f.calls.filter(c => c.op === 'openFace').length, 0);
  assert.equal(snapshot.faces[0].postscriptName, 'PS-0');
  assert.equal('source' in snapshot.faces[0], false);
});
test('필요 face만 chunk 단위로 읽고 정확한 bytes와 index 반환·slot 해제', async t => {
  const f = fixture(); cleanup(t, f);
  const s = await f.adapter.provider.getSnapshot(signal());
  const result = await f.adapter.provider.readFace('a', s.revision, signal());
  assert.deepEqual(Buffer.from(result.bytes), f.state.bytes);
  assert.equal(result.faceIndex, 0);
  assert.deepEqual(f.calls.filter(c => c.op === 'readChunk').map(c => c.length), [262144, 37856]);
  assert.equal(f.transfers.size, 0);
});
test('설치 CoreText와 관리 OS/2의 서로 다른 bits·style을 정규화', async t => {
  const f = fixture([face('bold', {style: 'Bold', traits: 2}),
    face('italic', {style: 'Light Italic', traits: 1}),
    face('oblique', {source: 'managed', weight: 500, traits: 512}),
    face('os2', {source: 'managed', weight: 700, traits: 32}),
    face('unknown', {style: 'Book'}), face('empty', {style: ''}),
    face('inherited', {style: 'constructor'})]); cleanup(t, f);
  const {faces} = await f.adapter.provider.getSnapshot(signal());
  assert.deepEqual(faces.map(f => [f.id, f.weight, f.slant]),
    [['oblique', 500, 'oblique'], ['os2', 700, 'normal'], ['bold', 700, 'normal'], ['italic', 300, 'italic']]);
});
test('빈 필수 이름·중복 ID·미지원은 제외하고 빈 alias는 제거', async t => {
  const f = fixture([face('a', {aliases: ['', ' ', '별칭']}), face('bad', {family: ''}),
    face('dup'), face('dup'), face('off', {limitation: 'disabled'})]); cleanup(t, f);
  const s = await f.adapter.provider.getSnapshot(signal());
  assert.deepEqual(s.faces.map(f => f.id), ['a']);
  assert.deepEqual(s.faces[0].aliases, ['별칭']);
});
test('선택된 관리 글꼴은 동명 설치 글꼴보다 우선, 다른 굵기는 유지', async t => {
  const regular = face('os', {family: 'Shared', fullName: 'Shared Regular', postScriptName: 'Shared-Regular'});
  const f = fixture([regular, {...regular, id: 'managed', source: 'managed', weight: 400},
    face('bold', {family: 'Shared', style: 'Bold', traits: 2})]); cleanup(t, f);
  const s = await f.adapter.provider.getSnapshot(signal());
  assert.deepEqual(s.faces.map(f => f.id), ['managed', 'bold']);
});
test('관리 충돌·미지원·잘못된 metadata는 동명 설치 fallback을 차단', async t => {
  for (const change of [{limitation: 'conflict'}, {limitation: 'unsupported'}, {fullName: ''}]) {
    const f = fixture([face('os', {family: 'Shared'}),
      face('managed', {family: 'Shared', source: 'managed', weight: 400, ...change})]); cleanup(t, f);
    assert.equal((await f.adapter.provider.getSnapshot(signal())).faces.length, 0);
  }
});
test('bounded queue가 여러 요청을 처리해도 native transfer는 최대 2개', async t => {
  const f = fixture(Array.from({length: 8}, (_, i) => face(`${i}`))); cleanup(t, f);
  const s = await f.adapter.provider.getSnapshot(signal());
  await Promise.all(s.faces.map(face => f.adapter.provider.readFace(face.id, s.revision, signal())));
  assert.equal(f.state.highWater, 2);
  assert.equal(f.transfers.size, 0);
});
test('일시 busy는 제한 재시도로 복구', async t => {
  let tries = 0;
  const f = fixture(undefined, {before: m => { if (m.op === 'openFace' && ++tries < 4) throw Error('busy'); }}); cleanup(t, f);
  const s = await f.adapter.provider.getSnapshot(signal());
  await f.adapter.provider.readFace('a', s.revision, signal());
  assert.equal(tries, 4);
});
test('지속 busy는 세대 자동 복구 1회 후 중단, 외부 변경으로 다시 복구 가능', async t => {
  const f = fixture(undefined, {before: m => { if (m.op === 'openFace') throw Error('busy'); }}); cleanup(t, f);
  let changes = 0;
  const off = f.adapter.provider.subscribe(() => changes++);
  let s = await f.adapter.provider.getSnapshot(signal());
  await assert.rejects(f.adapter.provider.readFace('a', s.revision, signal()), /busy/);
  await new Promise(resolve => setTimeout(resolve, 1050));
  assert.equal(changes, 1);
  const next = await f.adapter.provider.getSnapshot(signal());
  assert.notEqual(next.revision, s.revision);
  await assert.rejects(f.adapter.provider.readFace('a', next.revision, signal()), /busy/);
  await new Promise(resolve => setTimeout(resolve, 1050));
  assert.equal(changes, 1);
  off(); f.events.dispatchEvent(new Event('alhangeul-fonts-changed'));
  assert.equal(changes, 1);
});
test('catalog 중간 stale은 handshake부터 재시도', async t => {
  let once = true;
  const f = fixture(undefined, {before: (m, state) => { if (m.op === 'catalog' && once) { once = false; state.revision = 'r2'; } }}); cleanup(t, f);
  const s = await f.adapter.provider.getSnapshot(signal());
  assert.match(s.revision, /r2$/);
  assert.equal(f.calls.filter(c => c.op === 'handshake').length, 2);
});
test('동일 이름 bytes 변경 알림과 document token 교체 후 이전 reference 거부', async t => {
  const f = fixture(); cleanup(t, f);
  const old = await f.adapter.provider.getSnapshot(signal());
  f.state.token = 'load-2'; f.state.revision = 'r2';
  f.adapter.refresh();
  const next = await f.adapter.provider.getSnapshot(signal());
  await assert.rejects(f.adapter.provider.readFace('a', old.revision, signal()), /staleGeneration/);
  assert.notEqual(next.revision, old.revision);
  await f.adapter.provider.readFace('a', next.revision, signal());
  assert.equal(f.calls.filter(c => c.op === 'openFace').every(c => c.loadToken === 'load-2'), true);
});
test('metadata 요청 취소는 호출자에 즉시 반영하고 공유 준비를 손상하지 않음', async t => {
  const gate = deferred();
  const f = fixture(undefined, {before: m => m.op === 'handshake' ? gate.promise : undefined}); cleanup(t, f);
  const abort = new AbortController();
  const first = f.adapter.provider.getSnapshot(abort.signal);
  abort.abort(); await assert.rejects(first, {name: 'AbortError'});
  gate.resolve();
  assert.equal((await f.adapter.provider.getSnapshot(signal())).faces.length, 1);
});
test('취소 무시한 늦은 openFace 응답도 close하고 bytes를 게시하지 않음', async t => {
  const gate = deferred(), entered = deferred();
  const f = fixture(undefined, {open: async result => { entered.resolve(); await gate.promise; return result; }}); cleanup(t, f);
  const s = await f.adapter.provider.getSnapshot(signal());
  const abort = new AbortController();
  const read = f.adapter.provider.readFace('a', s.revision, abort.signal);
  await entered.promise;
  abort.abort(); await assert.rejects(read, {name: 'AbortError'});
  gate.resolve(); await tick(); await tick();
  assert.equal(f.transfers.size, 0);
  assert.equal(f.calls.filter(c => c.op === 'readChunk').length, 0);
  assert.equal(f.calls.some(c => c.op === 'cancel'), true);
});
test('generation 변경으로 진행 중 read 및 대기 read 취소·늦은 응답 폐기', async t => {
  const gate = deferred(), entered = deferred(); let count = 0;
  const f = fixture([face('a'), face('b'), face('c')], {open: async result => {
    if (++count === 2) entered.resolve(); await gate.promise; return result;
  }}); cleanup(t, f);
  const s = await f.adapter.provider.getSnapshot(signal());
  const results = Promise.allSettled(s.faces.map(face => f.adapter.provider.readFace(face.id, s.revision, signal())));
  await entered.promise; f.adapter.refresh();
  const settled = await results;
  assert.equal(settled.every(r => r.status === 'rejected' && r.reason.name === 'AbortError'), true);
  gate.resolve(); await tick(); await tick();
  assert.equal(f.calls.filter(c => c.op === 'openFace').length, 2);
  assert.equal(f.transfers.size, 0);
});
test('손상 chunk 또는 metadata와 다른 face는 반환하지 않고 transfer 해제', async t => {
  for (const override of [{chunk: c => ({...c, offset: c.offset + 1})},
    {chunk: c => ({...c, data: 'AA=='})}, {open: r => ({...r, weight: 700})}]) {
    const f = fixture(undefined, override); cleanup(t, f);
    const s = await f.adapter.provider.getSnapshot(signal());
    await assert.rejects(f.adapter.provider.readFace('a', s.revision, signal()), /invalidResponse|faceMismatch/);
    assert.equal(f.transfers.size, 0);
  }
});
test('dispose는 provider 연결과 변경 구독을 해제하고 후속 요청 거부', async () => {
  const f = fixture();
  await f.adapter.connect(); let changed = 0;
  f.adapter.provider.subscribe(() => changed++);
  await f.adapter.dispose();
  f.events.dispatchEvent(new Event('alhangeul-fonts-changed'));
  assert.equal(f.api.getState().active, false);
  assert.equal(changed, 0);
  await assert.rejects(f.adapter.provider.getSnapshot(signal()), {name: 'AbortError'});
});

test('잘못된 catalog 진행·총량은 무한 paging이나 과다 목록으로 이어지지 않음', async t => {
  for (const catalog of [r => ({...r, nextOffset: 0}), r => ({...r, total: 25000}), r => ({...r, faces: [null]})]) {
    const f = fixture(undefined, {catalog}); cleanup(t, f);
    await assert.rejects(f.adapter.provider.getSnapshot(signal()), /invalidResponse/);
    assert.equal(f.calls.filter(c => c.op === 'catalog').length, 1);
    assert.equal(f.calls.filter(c => c.op === 'openFace').length, 0);
  }
});
test('대기열은 64건 한도, 이미 취소한 요청은 native 읽기 없음', async t => {
  const gate = deferred(), entered = deferred(); let opened = 0;
  const f = fixture(Array.from({length: 67}, (_, i) => face(`${i}`)), {open: async result => {
    if (++opened === 2) entered.resolve(); await gate.promise; return result;
  }}); cleanup(t, f);
  const s = await f.adapter.provider.getSnapshot(signal());
  const controller = new AbortController(); controller.abort();
  await assert.rejects(f.adapter.provider.readFace('0', s.revision, controller.signal), {name: 'AbortError'});
  assert.equal(f.calls.some(c => c.op === 'openFace'), false);
  const reads = s.faces.slice(0, 66).map(face => f.adapter.provider.readFace(face.id, s.revision, signal()));
  const results = Promise.allSettled(reads);
  await entered.promise;
  await assert.rejects(f.adapter.provider.readFace('66', s.revision, signal()), /busy/);
  f.adapter.refresh();
  assert.equal((await results).every(r => r.status === 'rejected'), true);
  gate.resolve(); await tick(); await tick();
  assert.equal(f.transfers.size, 0);
});
test('목록 준비 중 dispose하면 늦은 연결 성공을 보고하지 않음', async () => {
  const gate = deferred(), entered = deferred();
  const f = fixture(undefined, {before: m => { if (m.op === 'handshake') { entered.resolve(); return gate.promise; } }});
  const connection = f.adapter.connect();
  const rejected = assert.rejects(connection, {name: 'AbortError'});
  await entered.promise; await f.adapter.dispose(); gate.resolve();
  await rejected;
  assert.equal(f.api.getState().active, false);
});
