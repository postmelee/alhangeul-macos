const {test} = require('node:test');
const assert = require('node:assert/strict');
const {pathToFileURL} = require('node:url');
const path = require('node:path');
const adapter = import(pathToFileURL(path.resolve(__dirname, '../studio-font-menu-adapter.mjs')));

const old = 'c9095c5f67632e6721e800ccc7fb43ea49d26682';
const target = '981ce66b4183b13c1a3b5907e04a8969c8c42034';
const main = 'src/main.ts';
const bridge = 'src/core/wasm-bridge.ts';
const render = import(pathToFileURL(path.resolve(__dirname, '../studio-initial-render-adapter.mjs')));
const canvas = 'src/view/canvas-view.ts';
const local = '@/core/local-fonts';
const bindings = 'fonts: { setProvider: setHostFontProvider, getState: getHostFontState },';
const hostImport = `import {
  hostFontLayoutEnabled, setHostFontProvider,
  getHostFontState, type LocalFontRecord,
} from '${local}';`;
const supplemental = `import { loadStoredLocalFonts } from "${local}";`;
const candidateBridge = `import { releaseHostLayoutPrograms, hostFontLayoutEnabled, hasHostFontProvider,
  resolveRendererLocalFontCandidates, type LocalFontRecord } from './local-fonts';
class WasmBridge {
  private canvasMetrics = new CanvasMetricSession();
  async render() {
    const metafileFontGeneration = 0;
    releaseHostLayoutPrograms();
  }
}`;

test('v0.9.1은 여러 local-fonts import 중 호스트 제공자 value 선언만 확장', async () => {
  const {adaptSource} = await adapter;
  const decoy = `/* import { setHostFontProvider } from '${local}'; */`;
  const other = "import { setHostFontProvider as alternateProvider } from './other';";
  const result = adaptSource([decoy, other, hostImport, supplemental, bindings].join('\n'), main, 'upstream');
  assert.ok(result.startsWith([decoy, other].join('\n')));
  assert.match(result, /import \{ resolveHostOutputFonts,\s*hostFontLayoutEnabled, setHostFontProvider/);
  assert.ok(result.includes(supplemental));
  assert.match(result, /resolveOutputRequests:\s*\(requests/);
});

test('기존 v0.9.1 후보 resolver와 upstream 해제 호출을 중복·제거하지 않음', async () => {
  const {adaptSource} = await adapter;
  const result = adaptSource(candidateBridge, bridge, 'upstream');
  const decl = result.match(/import\s*\{([^{}]+)\}\s*from '\.\/local-fonts';/)[1];
  assert.equal((decl.match(/\bresolveRendererLocalFontCandidates\b/g) ?? []).length, 1);
  assert.equal((decl.match(/\bloadRendererLocalFont\b/g) ?? []).length, 1);
  assert.match(result, /releaseHostLayoutPrograms\(\);/);
  assert.match(result, /await this.prepareDeclaredHostFonts\(current\)/);
});

test('주석 decoy, 대상 누락·중복, required alias·type 전용은 거부', async () => {
  const {adaptSource} = await adapter;
  const drift = /Studio font menu adapter drift: src\/main.ts import/;
  const run = prefix => adaptSource(prefix + '\n' + bindings, main, 'upstream');
  assert.throws(() => run(`/* ${hostImport} */\n${supplemental}`), drift);
  assert.throws(() => run(hostImport.replace(local, './other')), drift);
  assert.throws(() => run(hostImport + '\n' + hostImport), drift);
  assert.throws(() => run(hostImport.replace('setHostFontProvider', 'type setHostFontProvider')), drift);
  assert.throws(() => run(hostImport + `\nimport { type resolveHostOutputFonts } from '${local}';`), drift);
  assert.throws(() => run(hostImport + `\nimport { resolveHostOutputFonts as renamed } from '${local}';`), drift);
  assert.throws(() => run(hostImport + `\nimport { different as resolveHostOutputFonts } from '${local}';`), drift);
});

test('v0.9.0은 임시 보정, 검증된 upstream 첫 화면 계약은 부작용 없이 사용', async () => {
  const {adaptSource, sourcePaths} = await adapter;
  const {chooseInitialRenderMode, initialRenderEdits} = await render;
  const legacy = Object.fromEntries(Object.entries(initialRenderEdits).map(([p, edits]) =>
    [p, edits.map(([before]) => before).join('\n')]));
  const modern = {
    [main]: [
      'signal: AbortSignal,\n  options: { suppressDialogs?: boolean;',
      'await canvasView?.loadDocument();\n    signal.throwIfAborted();',
      'inputHandler?.activateWithCaretPosition();',
    ].join('\n'),
    [canvas]: [
      'ready: this.loadPreparedDocument()',
      'while (current() && this.rendererSelectionPending)',
      "this.updateVisiblePages('initial');\n      for (const recovery of recoveries) await recovery;",
      "throw new Error('첫 화면의 페이지를 그리지 못했습니다.');",
    ].join('\n'),
  };
  assert.equal(sourcePaths.length, 6);
  assert.equal(chooseInitialRenderMode(old, legacy), 'legacy');
  assert.equal(chooseInitialRenderMode(target, modern), 'upstream');
  assert.equal(chooseInitialRenderMode('a'.repeat(40), modern), 'upstream');
  assert.equal(chooseInitialRenderMode('b'.repeat(40), legacy), 'legacy');
  const drift = /Studio initial-render contract drift/;
  assert.throws(() => chooseInitialRenderMode(old, modern), drift);
  assert.throws(() => chooseInitialRenderMode(target, legacy), drift);
  assert.throws(() => chooseInitialRenderMode('c'.repeat(40), {[main]: modern[main], [canvas]: legacy[canvas]}), drift);
  assert.throws(() => chooseInitialRenderMode('d'.repeat(40), {...modern, [canvas]: modern[canvas] + modern[canvas]}), drift);
  assert.equal(adaptSource(modern[canvas], canvas, 'upstream'), modern[canvas]);
});
