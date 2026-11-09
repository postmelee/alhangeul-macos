// 앱 소유 목록·출력 선택 연결. upstream 파일·renderer·편집 명령은 수정하지 않는다.
export const receiptName = 'alhangeul-font-menu-adapter.json';
export const buildCommand = 'node scripts/build-rhwp-studio.mjs --upstream-dir <checkout>';
export const sourcePaths = ['src/core/local-fonts.ts', 'src/ui/toolbar.ts', 'src/ui/options-dialog.ts', 'src/main.ts', 'src/core/wasm-bridge.ts'];

export const outputResolverSource = `
export async function resolveHostOutputFonts(requests: readonly {
  key: string; family: string; weight: number; slant: 'normal' | 'italic' | 'oblique'; hasStroke?: boolean;
}[], allowsCanvasBold: (family: string) => boolean = () => false) {
  if (!hasHostFontProvider()) throw new Error('Output host provider unavailable');
  await prepareHostFontCatalog();
  const state = getHostFontState();
  if (state.lastError !== null || !state.active || !Array.isArray(requests) || requests.length > 2048
    || new Set(requests.map(r => r?.key)).size !== requests.length) throw new Error('Invalid output catalog/request');
  currentHostRecords();
  const selections = requests.map(request => {
    if (!request || typeof request.key !== 'string' || request.key.length > 1024 || !request.key.trim()
      || typeof request.family !== 'string' || !request.family.trim() || request.family.length > 1024
      || !Number.isInteger(request.weight) || request.weight < 1 || request.weight > 1000
      || !['normal','italic','oblique'].includes(request.slant)) throw new Error('Invalid output font request');
    let record = resolveRendererLocalFont(request.family, request);
    let status = 'selected';
    if (!record && request.weight === 700 && request.slant === 'normal' && !request.hasStroke
      && allowsCanvasBold(request.family)) {
      const candidates = hostLookup.aliases.get(normalizeFontAlias(request.family)) ?? [];
      if (candidates.length === 1 && candidates[0].hostReference?.face.weight === 400
        && candidates[0].hostReference.face.slant === 'normal') {
        record = candidates[0];
        status = 'canvasBold';
      }
    }
    const reference = record?.hostReference;
    if (reference) return {key: request.key, status, id: reference.face.id,
      postscriptName: reference.face.postscriptName, weight: reference.face.weight, slant: reference.face.slant};
    return {key: request.key, status: hostLookup.aliases.has(normalizeFontAlias(request.family)) ? 'unavailable' : 'absent'};
  });
  if (state.generation !== getHostFontState().generation) throw new Error('Stale output catalog');
  return {generation: state.generation, revision: hostFontSource.references()[0]?.revision ?? null, selections};
}
`;

// portable SVG와 같은 metrics transaction의 layer tree만 대조한다.
// core v0.8.7의 일반 textRun 합성 Bold(0.02 em)를 실제 Bold 요청으로 교체한다.
// face 선택·지원 불가 판정은 native 출력 job과 공식 matcher가 담당한다.
export const outputPageSource = `
function normalizeHostOutputSvg(svg: string, tree: unknown): string {
  type Row = Record<string, any>;
  const page = tree as Row;
  if (page?.schemaVersion !== 1 || page.schemaMinorVersion !== 23
    || page.unit !== 'px' || page.coordinateSystem !== 'page-top-left-y-down') return svg;
  const primary = (family: string) => family.split(',')[0].trim().replace(/^(['"])(.*)\\1$/, '$2').toLowerCase();
  const key = (text: string, family: string, x: number, y: number, size: number) =>
    JSON.stringify([text, primary(family), x.toFixed(3), y.toFixed(3), size.toFixed(3)]);
  const hints = new Map<string, {color: string; count: number}>();
  const pending: Row[] = [page.root]; let visited = 0, clusters = 0;
  while (pending.length) {
    const node = pending.pop()!;
    if (!node || ++visited > 65536) throw Error('Output layer limit');
    if (node.kind === 'group') pending.push(...node.children);
    else if (node.kind === 'clipRect') pending.push(node.child);
    else if (node.kind === 'leaf') for (const op of node.ops as Row[]) {
      if (++visited > 65536) throw Error('Output operation limit');
      const s = op.style, t = op.placement?.runToPage;
      if (op.type !== 'textRun' || s?.bold !== true || s.italic || s.outlineType || s.shadowType
        || s.emboss || s.engrave || s.superscript || s.subscript || s.ratio !== 1
        || op.rotation !== 0 || op.isVertical || op.orientation !== 'horizontal' || op.charOverlap
        || !t || t.a !== 1 || t.b !== 0 || t.c !== 0 || t.d !== 1 || op.placement.baselineY !== 0
        || !Number.isFinite(t.e) || !Number.isFinite(t.f) || !(s.fontSize > 0)
        || typeof s.fontFamily !== 'string' || typeof s.color !== 'string'
        || !Array.isArray(op.clusters)) continue;
      for (const cluster of op.clusters as Row[]) {
        if (++clusters > 65536) throw Error('Output cluster limit');
        const range = cluster.textRangeUtf16, origin = cluster.origin;
        if (cluster.projection !== 'verbatim' || !range || !origin || !Number.isFinite(origin.x)
          || origin.y !== 0 || !Number.isInteger(range.start) || !Number.isInteger(range.end)
          || range.start < 0 || range.end <= range.start || range.end > op.text.length) continue;
        const text = op.text.slice(range.start, range.end);
        const id = key(text, s.fontFamily, t.e + origin.x, t.f, s.fontSize);
        const prior = hints.get(id);
        hints.set(id, {color:s.color.toLowerCase(), count:(prior?.count ?? 0) + 1});
      }
    }
  }
  if (!hints.size) return svg;
  const parsed = new DOMParser().parseFromString(svg, 'image/svg+xml');
  if (parsed.querySelector('parsererror')) throw Error('Invalid output SVG');
  const nodes = parsed.querySelectorAll('text');
  if (nodes.length > 65536) throw Error('Output SVG limit');
  const matches = new Map<string, Element[]>();
  for (const node of nodes) {
    // CSS·transform·자식 요소가 있는 복잡한 text의 효과는 추측하지 않는다.
    if (node.children.length || node.closest('[transform]') || node.hasAttribute('style')) continue;
    const x = Number(node.getAttribute('x')), y = Number(node.getAttribute('y'));
    const size = Number(node.getAttribute('font-size'));
    if (!node.hasAttribute('x') || !node.hasAttribute('y') || !Number.isFinite(x)
      || !Number.isFinite(y) || !(size > 0)) continue;
    const id = key(node.textContent ?? '', node.getAttribute('font-family') ?? '', x, y, size);
    const hint = hints.get(id);
    if (!hint || hint.count !== 1 || node.getAttribute('fill')?.toLowerCase() !== hint.color
      || node.getAttribute('stroke')?.toLowerCase() !== hint.color
      || Math.abs(Number(node.getAttribute('stroke-width')) - size * 0.02) > 0.00051
      || ![null, 'normal', '400'].includes(node.getAttribute('font-weight'))) continue;
    const list = matches.get(id) ?? []; list.push(node); matches.set(id, list);
  }
  for (const list of matches.values()) {
    if (list.length !== 1) continue;
    list[0].setAttribute('font-weight', '700');
    list[0].removeAttribute('stroke'); list[0].removeAttribute('stroke-width');
  }
  return new XMLSerializer().serializeToString(parsed);
}

async function getHostOutputPageSvg(page: number): Promise<string> {
  if (!Number.isInteger(page) || page < 0 || page >= wasm.pageCount) throw Error('Invalid output page');
  // await를 transaction 안에 넣지 않는다. 화면의 Canvas metrics는 finally에서 복원된다.
  return wasm.withPortableMetrics(() => normalizeHostOutputSvg(wasm.renderPageSvg(page), wasm.getPageLayerTreeObject(page)));
}
`;

function replaceOnce(source, before, after, label) {
  if (source.split(before).length !== 2) throw Error(`Studio font menu adapter drift: ${label}`);
  return source.replace(before, after);
}

// 공식 WasmBridge 클래스에 삽입한다. 사용 가능한 프로그램의 선택과 조판은 core가 수행한다.
const declaredHostFontMethods = `
  private readonly hostHftFamilies = new Set(FONT_RULE_SUBSTITUTION_TABLES.flatMap(table =>
    table.filter(([, type]) => type === 2).map(([name]) => name)));
  private declaredHostFonts: { document: number; host: number; environmentId: string | null; cffFamilies: Set<string> } | null = null;

  usesHostHftRegular(family: string): boolean {
    const state = this.declaredHostFonts;
    return state?.document === this._documentGeneration && state.host === getHostFontState().generation
      && state.cffFamilies.has(family);
  }

  private async prepareDeclaredHostFonts(current: () => boolean): Promise<void> {
    const doc = this.doc;
    if (!doc) return;
    if (!hasHostFontProvider()) {
      const previous = this.declaredHostFonts;
      if (previous?.document === this._documentGeneration && previous.environmentId &&
        JSON.parse(doc.getDocumentFontSelectionPlan()).environmentId === previous.environmentId) doc.setFontEnvironment(undefined);
      this.declaredHostFonts = null;
      return;
    }
    await prepareHostFontCatalog();
    if (!current()) return;
    const host = getHostFontState();
    const generation = this._documentGeneration;
    const previous = this.declaredHostFonts;
    if (previous?.document === generation && previous.host === host.generation) return;
    const plan = JSON.parse(doc.getDocumentFontSelectionPlan()) as DocumentFontSelectionPlan;
    const owned = previous?.document === generation ? previous.environmentId : null;
    if (plan.environmentId !== null && plan.environmentId !== owned) return;
    const programs = [];
    const names = new Set(plan.requests.map(request => request.source).filter(name => this.hostHftFamilies.has(name)));
    if (names.size > 1024) return;
    for (const query of names) {
      if (plan.embeddedFamilies?.includes(query)) continue;
      const records = resolveRendererLocalFontCandidates(query, { weight: 400, slant: 'normal' });
      if (records.length !== 1 || !records[0].hostReference) continue;
      const data = await loadRendererLocalFont(records[0]).catch(() => null);
      if (!current() || host.generation !== getHostFontState().generation) return;
      if (!data || data.faceIndex || data.bytes.byteLength < 12) continue;
      const signature = new DataView(data.bytes).getUint32(0);
      const trueType = signature === 0x00010000 || signature === 0x74727565;
      const openTypeCff = signature === 0x4f54544f;
      if ((!trueType && !openTypeCff) || !fontProgramOwnsFamily(data.bytes, query)) continue;
      const hash = blake3(new Uint8Array(data.bytes));
      if (!current() || host.generation !== getHostFontState().generation) return;
      programs.push({ query, family: query, programId: bytesToHex(hash), trueType, openTypeCff });
    }
    if (!current() || host.generation !== getHostFontState().generation
      || JSON.parse(doc.getDocumentFontSelectionPlan()).environmentId !== plan.environmentId) return;
    const environment = doc.buildFontEnvironmentFromAvailablePrograms(JSON.stringify({programs}));
    const id = JSON.parse(environment)?.id ?? null;
    if (id !== null || owned !== null) doc.setFontEnvironment(id !== null ? environment : undefined);
    this.declaredHostFonts = { document: generation, host: host.generation, environmentId: id,
      cffFamilies: new Set(programs.filter(row => row.openTypeCff).map(row => row.family)) };
  }
`;

export function adaptSource(source, path) {
  if (path === sourcePaths[4]) {
    source = replaceOnce(source, 'import { hasHostFontProvider,', "import { fontProgramOwnsFamily } from './canvas-intrinsic-font.mjs';\nimport { FONT_RULE_SUBSTITUTION_TABLES } from './font-rule-runtime';\nimport { resolveRendererLocalFontCandidates, loadRendererLocalFont, hasHostFontProvider,", path);
    source = replaceOnce(source, '  private canvasMetrics =', declaredHostFontMethods + '\n  private canvasMetrics =', path);
    return replaceOnce(source, '    const metafileFontGeneration =', '    await this.prepareDeclaredHostFonts(current);\n    if (!current()) return false;\n    const metafileFontGeneration =', path);
  }

  if (path === sourcePaths[0]) {
    source = replaceOnce(source,
      'export function getLocalFonts(options: GetLocalFontsOptions = {}): string[] {\n',
      `export function getLocalFonts(options: GetLocalFontsOptions = {}): string[] {
  // 알한글: 메뉴는 공급 가능한 family를 표시하고 style 선택은 기존 renderer에 맡긴다.
  if (hasHostFontProvider()) {
    return normalizeFamilies(currentHostRecords().map(record => record.family));
  }
`, path);
    if (source.includes('function resolveHostOutputFonts')) throw Error('Studio output adapter drift: duplicate resolver');
    return source + outputResolverSource;
  }
  if (path === sourcePaths[3]) {
    source = replaceOnce(source, 'import { setHostFontProvider,', 'import { resolveHostOutputFonts, setHostFontProvider,', path);
    return replaceOnce(source, 'fonts: { setProvider: setHostFontProvider, getState: getHostFontState },',
      'fonts: { setProvider: setHostFontProvider, getState: getHostFontState, resolveOutputRequests: (requests: Parameters<typeof resolveHostOutputFonts>[0]) => resolveHostOutputFonts(requests, family => wasm.usesHostHftRegular(family)), getOutputPageSvg: getHostOutputPageSvg },', path) + outputPageSource;
  }
  if (path === sourcePaths[1]) {
    source = replaceOnce(source,
      "import { getLocalFonts } from '@/core/local-fonts';",
      "import { getLocalFonts, onHostFontsChanged, prepareHostFontCatalog, getHostFontState } from '@/core/local-fonts';", path);
    return replaceOnce(source,
      "    eventBus.on('local-fonts-changed', () => {\n      this.refreshFontDropdown();\n    });",
      `    eventBus.on('local-fonts-changed', () => {
      this.refreshFontDropdown();
    });
    onHostFontsChanged(() => {
      // 이전 snapshot의 선택 항목은 즉시 폐기한다. 문서 선택값은 유지한다.
      this.closeFontMenu();
      const generation = getHostFontState().generation;
      void prepareHostFontCatalog().then(() => {
        if (getHostFontState().generation === generation && this.fontMenu) {
          this.renderFontMenu(this.fontMenu);
        }
      });
    });`, path);
  }
  if (path === sourcePaths[2]) {
    return replaceOnce(source,
      '    // ── 로컬 글꼴 섹션 ──\n',
      `    // 알한글은 browser 감지/저장과 별개인 native 설정에서 글꼴을 관리한다.
    const nativeCommand = (window as unknown as {
      __alhangeulHostBridgeRunNativeCommand?: (command: string) => boolean;
    }).__alhangeulHostBridgeRunNativeCommand;
    if (typeof nativeCommand === 'function') {
      const section = document.createElement('div');
      section.className = 'dialog-section';
      section.dataset.alhangeulFontSettings = '';
      const title = document.createElement('div');
      title.className = 'dialog-section-title';
      title.textContent = 'Mac 글꼴';
      const description = document.createElement('p');
      description.className = 'opt-desc';
      description.textContent = 'Mac에 설치된 글꼴의 사용 설정과 글꼴 가져오기는 앱의 글꼴 설정에서 관리합니다. 사용할 수 있는 글꼴은 상단 글꼴 목록에서 선택할 수 있습니다.';
      const button = document.createElement('button');
      button.className = 'dialog-btn opt-fontset-btn';
      button.textContent = '글꼴 설정 열기…';
      button.addEventListener('click', () => { nativeCommand('app:font-settings'); });
      section.append(title, description, button);
      panel.appendChild(section);
      return panel;
    }
    // ── 로컬 글꼴 섹션 ──
`, path);
  }
  throw Error(`Unexpected Studio adapter source: ${path}`);
}

export function fontMenuPlugin(sources, receipt) {
  const visited = new Set();
  return {
    name: 'alhangeul-host-font-menu', enforce: 'pre',
    transform(source, id) {
      const input = sources.find(row => row.absolute === id);
      if (!input) return;
      if (source !== input.original) throw Error(`Studio font menu source changed during build: ${input.path}`);
      visited.add(input.path);
      return {code: input.adapted, map: null};
    },
    generateBundle() {
      if (sourcePaths.some(path => !visited.has(path))) throw Error('Studio font menu adapter was not included');
      this.emitFile({type: 'asset', fileName: receiptName, source: JSON.stringify(receipt, null, 2) + '\n'});
    },
  };
}
