// Node 24의 type stripping으로 pinned TypeScript module을 수정 없이 실행한다.
import { readFile, writeFile, cp } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';

const [upstream, fontDirectory, output] = process.argv.slice(2, 5).map(value => resolve(value));
const studio = join(upstream, 'rhwp-studio');
const adapted = process.argv.includes('--adapted');
let modulePath = join(studio, 'src/core/local-fonts.ts');
if (adapted) {
  const {adaptSource} = await import('../../scripts/studio-font-menu-adapter.mjs');
  const copy = join(output, 'matcher-source');
  await cp(join(studio, 'src'), join(copy, 'src'), {recursive:true});
  modulePath = join(copy, 'src/core/local-fonts.ts');
  await writeFile(modulePath, adaptSource(await readFile(modulePath, 'utf8'), 'src/core/local-fonts.ts'));
}
const api = await import(pathToFileURL(modulePath));
const { collectHostFontRequests } = await import(pathToFileURL(adapted
  ? join(output, 'matcher-source/src/core/host-font-requests.ts') : join(studio, 'src/core/host-font-requests.ts')));
const metadata = JSON.parse(await readFile(join(output, 'metadata.json'), 'utf8'));
let revision = 'probe-1', onChange, reads = 0;
let faces = metadata.faces.map(({ id, family, fullName, postscriptName, style, aliases, weight }) =>
  ({ id, family, fullName, postscriptName, style, aliases: [...new Set([...aliases, '고운바탕'])], weight, slant: 'normal' }));
const provider = {
  async getSnapshot() { return { revision, faces }; },
  async readFace(id, requestedRevision, signal) {
    assert.equal(requestedRevision, revision); assert.equal(signal.aborted, false); reads++;
    const row = metadata.faces.find(f => f.id === id);
    const buffer = await readFile(join(fontDirectory, row.file));
    assert.equal(createHash('sha256').update(buffer).digest('hex'), row.sha256);
    return { bytes: buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength), faceIndex: 0 };
  },
  subscribe(listener) { onChange = listener; return () => {}; },
};
await api.setHostFontProvider(provider);
await api.prepareHostFontCatalog();
assert.equal(api.getHostFontState().count, 2);
assert.equal(reads, 0);
if (adapted) {
  const requests = [['Gowun Batang',400],['Gowun Batang',700],['Gowun Batang Regular',400],
    ['GowunBatang-Bold',700],['바탕',400],['돋움',700],['serif',400],['sans-serif',400],
    ['sans-serif',700]].map(([family,weight],i)=>({key:String(i),family,weight,slant:'normal'}));
  const result = await api.resolveHostOutputFonts(requests);
  assert.deepEqual(result.selections.slice(0,4).map(s=>s.id), ['regular','bold','regular','bold']);
  assert.ok(result.selections.slice(4).every(s=>s.status==='absent'));
  assert.equal(reads,0);
  await writeFile(join(output,'output-resolutions.json'),JSON.stringify({requests,...result},null,2)+'\n');
}
const cases = [];
function check(label, name, weight, slant, expected) {
  const record = api.resolveRendererLocalFont(name, { weight, slant });
  const actual = record?.hostReference?.face.id ?? null;
  assert.equal(actual, expected, label);
  cases.push({ label, name, weight, slant, selectedID: actual, postscriptName: record?.postscriptName ?? null });
  return record;
}
const regular = check('family-regular', 'Gowun Batang', 400, 'normal', 'regular');
const bold = check('family-bold', 'Gowun Batang', 700, 'normal', 'bold');
check('localized-regular', '고운바탕', 400, 'normal', 'regular');
check('localized-bold', '고운바탕', 700, 'normal', 'bold');
check('postscript-exact', 'GowunBatang-Regular', 700, 'italic', 'regular');
check('full-name-exact', 'Gowun Batang Bold', 400, 'normal', 'bold');
check('unsupported-italic', 'Gowun Batang', 400, 'italic', null);
check('missing-family', 'Stage568AbsentFont', 400, 'normal', null);
const text = (fontFamily, bold = false, type = 'textRun') => ({ type, style: { fontFamily, bold } });
const tree = { root: { kind: 'group', children: [
  { kind: 'leaf', ops: [text('"Gowun Batang", serif'), text('고운바탕', true)] },
  { kind: 'clipRect', child: { kind: 'leaf', ops: [text('GowunBatang-Bold', false, 'charOverlap')] } },
] } };
const selected = collectHostFontRequests(tree).map(r => r.hostReference.face.id).sort();
assert.deepEqual(selected, ['bold', 'regular']); assert.equal(reads, 0);
const data = await Promise.all(Array.from({ length: 8 }, () => api.loadRendererLocalFont(regular)));
assert.equal(reads, 1); assert.ok(data.every(d => d.bytes.byteLength === metadata.faces[0].bytes));
await api.loadRendererLocalFont(regular); assert.equal(reads, 2); // 영구 bytes cache가 아니다.
await api.loadRendererLocalFont(bold); assert.equal(reads, 3);
faces = [...faces, { ...faces[0], id: 'collision', postscriptName: 'Stage568Collision-Regular', fullName: 'Stage568 Collision' }];
revision = 'probe-2'; onChange(); await api.prepareHostFontCatalog();
check('ambiguous-family', 'Gowun Batang', 400, 'normal', null);
check('ambiguous-localized', '고운바탕', 400, 'normal', null);
assert.equal(await api.loadRendererLocalFont(regular), null); assert.equal(reads, 3);
await writeFile(join(output, 'matcher-results.json'), JSON.stringify({
  upstreamCommit: '1a76570e833917d15817415a53c09ad61ab3203f', cases,
  collectedIDs: selected, metadataReads: 0, eightConcurrentReads: 1, repeatedReadTotal: 2,
  finalReads: reads, staleRead: 'rejected', bytesCache: 'in-flight-only',
}, null, 2) + '\n');
await api.setHostFontProvider(null);
console.log(`공식 matcher ${cases.length}개 조건, collection·in-flight·stale 검사 통과`);
