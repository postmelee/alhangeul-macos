// 앱 소유 목록·출력 선택 연결. upstream 파일·renderer·편집 명령은 수정하지 않는다.
export const receiptName = 'alhangeul-font-menu-adapter.json';
export const buildCommand = 'node scripts/build-rhwp-studio.mjs --upstream-dir <checkout>';
export const sourcePaths = ['src/core/local-fonts.ts', 'src/ui/toolbar.ts', 'src/ui/options-dialog.ts', 'src/main.ts'];

export const outputResolverSource = `
export async function resolveHostOutputFonts(requests: readonly {
  key: string; family: string; weight: number; slant: 'normal' | 'italic' | 'oblique'; hasStroke?: boolean;
}[]) {
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
    const record = resolveRendererLocalFont(request.family, request);
    const reference = record?.hostReference;
    if (reference) return {key: request.key, status: 'selected', id: reference.face.id,
      postscriptName: reference.face.postscriptName, weight: reference.face.weight, slant: reference.face.slant};
    return {key: request.key, status: hostLookup.aliases.has(normalizeFontAlias(request.family)) ? 'unavailable' : 'absent'};
  });
  if (state.generation !== getHostFontState().generation) throw new Error('Stale output catalog');
  return {generation: state.generation, revision: hostFontSource.references()[0]?.revision ?? null, selections};
}
`;

function replaceOnce(source, before, after, label) {
  if (source.split(before).length !== 2) throw Error(`Studio font menu adapter drift: ${label}`);
  return source.replace(before, after);
}

export function adaptSource(source, path) {
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
      'fonts: { setProvider: setHostFontProvider, getState: getHostFontState, resolveOutputRequests: resolveHostOutputFonts },', path);
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
